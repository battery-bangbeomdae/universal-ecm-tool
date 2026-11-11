function tests=testModelAccumulation
tests=functiontests(localfunctions);
end
function testSequentialModelsDiskAndMemory(t)
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);d=string(tempname);mkdir(d);c=onCleanup(@()rmdir(d,'s')); %#ok<NASGU>
T=readtable(fullfile(root,'examples','REAL_D010_eis_12spectra.csv'),'TextType','string');T=T(T.spectrum_id==T.spectrum_id(1),:);file=fullfile(d,'eis.csv');writetable(T,file);
o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
x=uecm.workspaceLoad(file,o,"",struct(),struct());one=uecm.workspaceFit(x.Input,struct(),true,@(~)[]);verifyEqual(t,numel(one.Fits{1}.Alternatives),1);oldRC=one.Fits{1}.Alternatives{1}.Parameters;
M=table(one.Results.spectrum_id,42,'VariableNames',{'spectrum_id','storage_days'});one=uecm.addCustomAxis(one,M,"storage_days","Storage days","d","spectrum_id","test metadata");
m=uecm.Models.SessionModel();vm=uecm.ViewModels.MainViewModel(m);vm.acceptWorkspace(x.Input,one);vm.setOption('EISModels',"2RC");verifyNotEmpty(t,vm.Bundle.Results);
two=uecm.workspaceFit(vm.analysisInput(),vm.Bundle,true,@(~)[]);verifyEqual(t,sort(string(two.Fits{1}.CandidateScores.Model)),["1RC";"2RC"]);verifyEqual(t,findCandidate(two,"RC").Parameters,oldRC);verifyEqual(t,two.Results.custom_storage_days,42);
verifyEqual(t,two.Fits{1}.EvaluatedModels,["RC","2RC"]);verifyTrue(t,contains(two.CacheSummary,"새 피팅 1개"));
files=dir(fullfile(d,'ecm_result','**','fit_*.mat'));verifyEqual(t,numel(files),2);[~,order]=sort(string({files.name}));idx=order(end);saved=load(fullfile(files(idx).folder,files(idx).name),'bundle');verifyEqual(t,numel(saved.bundle.Fits{1}.Alternatives),2);
% Fresh workspace: both models visible even when only 2RC is checked.
o.EISModels="2RC";loaded=uecm.workspaceLoad(file,o,"",struct(),struct());verifyEqual(t,numel(loaded.Bundle.Fits{1}.Alternatives),2);verifyEqual(t,loaded.Bundle.Results.custom_storage_days,42);
again=uecm.workspaceFit(loaded.Input,struct(),true,@(~)[]);verifyTrue(t,contains(again.CacheSummary,"새 피팅 0개"));verifyEqual(t,numel(dir(fullfile(d,'ecm_result','**','fit_*.mat'))),2);
% Loading historical snapshot into a workspace must not erase newer candidates.
merged=uecm.workspaceLoad(file,o,"",loaded.Input,one);verifyEqual(t,numel(merged.Bundle.Fits{1}.Alternatives),2);
% Data and quality/profile edits must not pull candidates from different conditions.
changed=loaded.Input;changed.Settings.EISRelativeErrorLimit=.123;different=uecm.workspaceFit(changed,loaded.Bundle,false,@(~)[]);verifyEmpty(t,different.Results);
T.R_real_Ohm=T.R_real_Ohm+.001;writetable(T,file);different=uecm.workspaceLoad(file,o,"",struct(),struct());verifyEmpty(t,different.Bundle.Results);
end
function testMemoryOnlyAndMissingCoverage(t)
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
i=uecm.readInput(fullfile(root,'examples','REAL_D010_eis_12spectra.csv'),o);i.Data=i.Data(string(i.Data.spectrum_id)==string(i.Data.spectrum_id(1)),:);
a=uecm.workspaceFit(i,struct(),true,@(~)[]);i.Settings.EISModels="2RC";b=uecm.workspaceFit(i,a,true,@(~)[]);verifyEqual(t,numel(b.Fits{1}.Alternatives),2);
verifyEqual(t,findCandidate(a,"RC").Predicted,findCandidate(b,"RC").Predicted);
end
function c=findCandidate(b,kind)
a=uecm.candidatesOf(b.Fits{1});hit=find(cellfun(@(x)erase(string(x.Candidate),"+W")==kind,a),1);c=a{hit};
end
