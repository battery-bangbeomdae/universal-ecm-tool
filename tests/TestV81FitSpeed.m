classdef TestV81FitSpeed < matlab.unittest.TestCase
    properties
        Folder
        Prepared
        Input
        Baseline
    end
    methods(TestClassSetup)
        function fixture(t)
            app=fileparts(fileparts(mfilename('fullpath')));addpath(app);provenance=fullfile(app,'merge_provenance','v8_1_fit_speed');addpath(provenance);
            t.Folder=string(tempname);mkdir(t.Folder);t.addTeardown(@()rmdir(t.Folder,'s'));
            [t.Input,t.Prepared]=createFixture(app,t.Folder);
            t.Baseline=workspaceFitBaseline(t.Input,struct(),false,@(~)[],t.Prepared);
        end
    end
    methods(Test)
        function batchReadMatchesBaselineAndPreservesArchiveBytes(t)
            p=t.Prepared;files=dir(fullfile(p.FilePrepared{1}.Input.FittingRoot,'**','fit_*.mat'));before=readBytes(files);
            b=uecm.workspaceFit(t.Input,struct(),false,@(~)[],p);
            t.verifyEqual(b.Results,t.Baseline.Results);t.verifyEqual(b.Fits,t.Baseline.Fits);t.verifyEqual(readBytes(files),before);
        end
        function incompatibleAndCorruptArchiveAreIgnored(t)
            [p,root]=isolated(t.Prepared,t.Folder,"invalid");signature="different MATLAB version";bundle=t.Baseline;save(fullfile(root,'fit_wrong_version.mat'),'bundle','signature');
            writelines("deliberately corrupt test archive",fullfile(root,'fit_corrupt.mat'));
            expected=workspaceFitBaseline(p.Input,struct(),false,@(~)[],p);actual=uecm.workspaceFit(p.Input,struct(),false,@(~)[],p);
            t.verifyEmpty(actual.Results);t.verifyEqual(actual.Results,expected.Results);
        end
        function firstNewFitIsReusedByLaterInput(t)
            [p,~]=isolated(t.Prepared,t.Folder,"fresh");p.FilePrepared={p.FilePrepared{1},p.FilePrepared{1}};
            [actual,message]=uecm.workspaceFit(p.Input,struct(),true,@(~)[],p);
            t.verifyEqual(height(actual.Results),2);t.verifyTrue(contains(message,"새 피팅 1개 파일"));t.verifyTrue(contains(message,"재사용 1개 파일"));
            t.verifyEqual(actual.Fits{1}.Parameters,actual.Fits{2}.Parameters);
        end
        function newlyCreatedSpecificRootReplacesAncestorSearch(t)
            [p,root]=isolated(t.Prepared,t.Folder,"nested");ancestor=fullfile(t.Folder,'ancestor','ecm_result','matlab_uecm_cache_v1');mkdir(ancestor);
            requested=fullfile(t.Folder,'ancestor','child','ecm_result','matlab_uecm_cache_v1');p.FilePrepared{1}.Input.FittingRoot=string(requested);p.FilePrepared{2}=p.FilePrepared{1};p.FilePrepared=p.FilePrepared(1:2);
            [b,message]=uecm.workspaceFit(p.Input,struct(),true,@(~)[],p); %#ok<NASGU>
            t.verifyTrue(isfolder(requested));t.verifyEqual(height(b.Results),2);t.verifyTrue(contains(message,"새 피팅 1개 파일"));t.verifyTrue(contains(message,"백업 실패 0개"));
        end
        function identityIndexKeepsMissingAndPartialModelCoverage(t)
            o=uecm.defaults();o.EISModels=["RC","2RC"];o.EISAutoWarburg=false;
            q=struct('Input',struct('Settings',o),'Data',table(["S";"S"],["C";"C"],["T";"T"],["a";"b"],'VariableNames',{'source','cell','test','spectrum'}));
            a=struct('Identity',struct('source_id',"S",'cell_id',"C",'test_id',"T",'spectrum_id',"a"),'EvaluatedModels',["RC","2RC"]);
            b=a;b.Identity.spectrum_id="b";b.EvaluatedModels="RC";
            t.verifyEqual(uecm.missingEISModels(struct('Fits',{{b,a}}),q),"2RC");
            t.verifyEqual(uecm.missingEISModels(struct('Fits',{{a}}),q),["RC","2RC"]);
        end
    end
end
function contents=readBytes(files)
contents=cell(numel(files),1);
for k=1:numel(files),fid=fopen(fullfile(files(k).folder,files(k).name),'rb');c=onCleanup(@()fclose(fid));contents{k}=fread(fid,Inf,'*uint8');clear c;end
end
function [p,root]=isolated(original,folder,label)
p=original;root=fullfile(folder,label,'ecm_result','matlab_uecm_cache_v1');mkdir(root);
for k=1:numel(p.FilePrepared),p.FilePrepared{k}.Input.FittingRoot=string(root);end
p.Input=p.FilePrepared{1}.Input;
end

function [input,p]=createFixture(app,folder)
root=fullfile(folder,'fixtures','ecm_result','matlab_uecm_cache_v1');mkdir(root);parts=cell(1,3);o=uecm.defaults();o.CurrentSign="charge_positive";
files=dir(fullfile(app,'+uecm','**','*.m'));signature=string(version);
for k=1:numel(files),signature(end+1,1)=string(fileread(fullfile(files(k).folder,files(k).name)));end
for k=1:3
 file=fullfile(folder,"REAL_fixture_"+k+".csv");copyfile(fullfile(app,'examples','REAL_D014_hppc_one_pulse.csv'),file);
 input=uecm.readInput(file,o);input.FittingRoot=string(root);parts{k}=uecm.prepare(input);bundle=uecm.analyze(input,@(~)[],parts{k});
 sub=fullfile(root,string(k));mkdir(sub);
 for n=1:2,save(fullfile(sub,"fit_"+n+".mat"),'bundle','signature','-v7');end
end
p=parts{1};p.FilePrepared=parts;input=p.Input;
end
