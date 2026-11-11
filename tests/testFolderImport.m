function tests=testFolderImport
tests=functiontests(localfunctions);
end
function setup(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));
t.TestData.Folder=string(tempname);mkdir(t.TestData.Folder);
t.addTeardown(@()rmdir(t.TestData.Folder,'s'));
end
function testRecursiveFolderKeepsConditionsAndReportsFailures(t)
folder=t.TestData.Folder;mkdir(fullfile(folder,"nested"));
file=fullfile(folder,"nested","raw.csv");
writelines(["Instrument metadata"; ...
    "Time [s],Current [A],Voltage [V],SOC [%],SOH [%],Cycle,cell_id"; ...
    "0,0,4.1,80,95,10,CellA";"1,-1,4.0,79,95,10,CellA"],file);
writelines("reference",fullfile(folder,"README.txt"));
input=uecm.readFolder(folder);
verifyEqual(t,numel(input.Files),1);
verifyTrue(t,any(input.ImportLog.status=="unreadable"));
m=input.Mapping;
verifyEqual(t,input.Data.(m.soc),[80;79]);
verifyEqual(t,input.Data.(m.soh),[95;95]);
verifyEqual(t,string(input.Data.(m.cell)),["CellA";"CellA"]);
verifyEqual(t,input.Data.raw_source_row,[1;2]);
end
function testKnownMatrixMATUsesRawInputInsteadOfSessionLoader(t)
folder=t.TestData.Folder;file=fullfile(folder,"Cell28_100SOH_25degC_50SOC_10000.mat");
freq=logspace(3,-1,20)';z=.01+.02./(1+1i*2*pi*freq);
matrix=[freq,real(z),imag(z)];save(file,"matrix");
input=uecm.Models.SessionModel.loadFile(file,uecm.defaults(),"");
verifyEqual(t,input.Data.frequency_hz,freq);
verifyEqual(t,input.Data.z_real_ohm,real(z));
verifyEqual(t,input.Data.soc_pct,repmat(50,20,1));
verifyFalse(t,ismember('soh_pct',input.Data.Properties.VariableNames));
verifyTrue(t,isfield(input,'RawReport'));
settings=uecm.defaults();settings.Circuit="RC";
batch=uecm.readFolder(folder,settings);
bundle=uecm.analyze(batch);
verifyEqual(t,height(bundle.Results),1);
verifyEqual(t,bundle.Results.Rs_Ohm,.01,'AbsTol',1e-5);
output=uecm.exportBundle(bundle,folder);
verifyTrue(t,isfile(fullfile(output,'folder_import_log.csv')));
verifyTrue(t,isfile(fullfile(output,'raw_column_mapping.csv')));

end
function testMultipleRootsDeduplicateNestedAndRepeatedPaths(t)
r=t.TestData.Folder;mkdir(fullfile(r,'a'));mkdir(fullfile(r,'b'));
writelines(["frequency_hz,z_real_ohm,z_imag_ohm";"1,0.03,-0.01";"2,0.02,-0.01"],fullfile(r,'a','eis.csv'));
writelines(["time_s,current_A,voltage_V";"0,0,4.1";"1,-1,4.0"],fullfile(r,'b','hppc.csv'));
writelines("unreadable reference",fullfile(r,'b','note.txt'));
input=uecm.Models.SessionModel.loadFile([r;fullfile(r,'a');r],uecm.defaults(),"");
verifyEqual(t,numel(input.Files),2);verifyEqual(t,numel(unique(input.Files)),2);
verifyEqual(t,sum(input.ImportLog.status=="loaded"),2);
verifyTrue(t,any(input.ImportLog.status=="unreadable"));
verifyEqual(t,numel(input.ImportFolder),2);
settings=uecm.defaults();settings.Type="EIS";
input=uecm.readFolder([fullfile(r,'a');fullfile(r,'b')],settings);
verifyEqual(t,numel(input.Files),1);verifyTrue(t,any(input.ImportLog.status=="type_mismatch"));
end
function testFolderPickerAcceptsMultipleChildren(t)
r=t.TestData.Folder;mkdir(fullfile(r,'a'));mkdir(fullfile(r,'b'));
tm=timer('StartDelay',2,'TimerFcn',@completePicker,'ErrorFcn',@unblockPicker);
cleanup=onCleanup(@()delete(tm));start(tm);
folders=uecm.chooseFolders(r);
verifyEqual(t,sort(folders),sort([fullfile(r,'a');fullfile(r,'b')]));
end
function completePicker(~,~)
f=findall(groot,'Tag','ExperimentFolderPicker');
l=findall(f,'Tag','FolderCandidates');l.Value={'a','b'};
b=findall(f,'Tag','AddSelectedFolders');feval(b.ButtonPushedFcn,b,[]);
b=findall(f,'Tag','ImportChosenFolders');feval(b.ButtonPushedFcn,b,[]);
end
function unblockPicker(~,~)
f=findall(groot,'Tag','ExperimentFolderPicker');if ~isempty(f),uiresume(f);end
end
function testDeepParentWorkspaceRetainsAuditAndProgress(t)
r=t.TestData.Folder;leaf=r;
for k=1:8,leaf=fullfile(leaf,"level_"+k);mkdir(leaf);end
writelines(["frequency_hz,z_real_ohm,z_imag_ohm";"1,0.03,-0.01";"2,0.02,-0.01"],fullfile(leaf,'deep.csv'));
writelines("not a measurement",fullfile(r,'README.txt'));
mkdir(fullfile(r,'ecm_result','matlab_uecm_cache_v1','ignored'));
writelines(["frequency_hz,z_real_ohm,z_imag_ohm";"1,9,-9"],fullfile(r,'ecm_result','matlab_uecm_cache_v1','ignored','response.csv'));
messages=strings(0,1);out=uecm.workspaceLoad(r,uecm.defaults(),"",struct(),struct(),"append",@record);
verifyEqual(t,numel(uecm.effectiveInputs(out.Input)),1);verifyTrue(t,isfield(out.Input,'ImportLog'));verifyTrue(t,any(out.Input.ImportLog.status=="loaded"));verifyTrue(t,any(out.Input.ImportLog.status=="unreadable"));verifyEqual(t,out.Input.ImportFolder,r);verifyGreaterThan(t,numel(messages),2);verifyTrue(t,any(contains(messages,"파일 읽기")));
child=uecm.workspaceLoad(leaf,uecm.defaults(),"",out.Input,out.Bundle);
verifyEqual(t,numel(uecm.effectiveInputs(child.Input)),1);verifyTrue(t,any(child.Input.ImportLog.status=="unreadable"));verifyEqual(t,numel(child.Input.ImportFolder),2);
 function record(data),messages(end+1)=string(data.Message);end
end
function testPickerImportsCurrentParentDirectly(t)
r=t.TestData.Folder;mkdir(fullfile(r,'deep'));
tm=timer('StartDelay',1,'TimerFcn',@acceptCurrentRoot,'ErrorFcn',@unblockPicker);cleanup=onCleanup(@()delete(tm));start(tm);
folders=uecm.chooseFolders(r);verifyEqual(t,folders,r);
end
function acceptCurrentRoot(~,~)
f=findall(groot,'Tag','ExperimentFolderPicker');b=findall(f,'Tag','ImportCurrentFolder');feval(b.ButtonPushedFcn,b,[]);
end
