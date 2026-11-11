function tests=testImportSelection
tests=functiontests(localfunctions);
end
function setup(t)
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
t.TestData.Root=string(root);t.TestData.Folder=string(tempname);mkdir(t.TestData.Folder);
t.addTeardown(@()rmdir(t.TestData.Folder,'s'));
end
function testTemplateModeEnforcesRequestedDomain(t)
o=uecm.defaults();o.ImportMode="template";o.Type="EIS";
file=fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv');
input=uecm.readInput(file,o);verifyFalse(t,isfield(input,'RawReport'));
p=uecm.prepare(input);verifyFalse(t,p.Blocked);
o.Type="HPPC";verifyError(t,@()uecm.readInput(file,o),'uecm:InputType');
end
function testRawEISModeOnlyReadsRequestedWorkbookSheets(t)
file=fullfile(t.TestData.Folder,"mixed.xlsx");
time=(0:19)';T=table(time,ones(20,1),4*ones(20,1),'VariableNames',{'Time [s]','Current [A]','Voltage [V]'});
frequency=logspace(3,-1,20)';z=.01+.02./(1+1i*2*pi*frequency);
E=table(frequency,real(z),imag(z),'VariableNames',{'Frequency [Hz]','Zreal [Ohm]','Zimag [Ohm]'});
writetable(T,file,'Sheet','time_data');writetable(E,file,'Sheet','impedance');
o=uecm.defaults();o.ImportMode="raw";o.Type="EIS";
input=uecm.readInput(file,o);verifyEqual(t,unique(string(input.Data.raw_sheet)),"impedance");
p=uecm.prepare(input);verifyFalse(t,p.Blocked);verifyEqual(t,p.Type,"EIS");
end
function testFolderKeepsTypeAndLogsMismatchedFiles(t)
folder=t.TestData.Folder;
copyfile(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'),fullfile(folder,'eis.csv'));
copyfile(fullfile(t.TestData.Root,'examples','REAL_D014_hppc_one_pulse.csv'),fullfile(folder,'hppc.csv'));
o=uecm.defaults();o.ImportMode="template";o.Type="EIS";
input=uecm.readFolder(folder,o);
verifyEqual(t,numel(input.Files),1);
verifyTrue(t,any(input.ImportLog.status=="type_mismatch"));
verifyEqual(t,input.Settings.Type,"EIS");
p=uecm.prepare(input);verifyEqual(t,p.Type,"EIS");
end
function testBatchExplicitTypeIsNotReplacedByAuto(t)
files=[fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'); ...
    fullfile(t.TestData.Root,'examples','REAL_D014_hppc_one_pulse.csv')];
input=uecm.readInputs(files);input.Settings.Type="HPPC";
p=uecm.prepare(input);
verifyEqual(t,p.FilePrepared{1}.Type,"HPPC");
verifyTrue(t,p.FilePrepared{1}.Blocked);
end
function testMixedWorkbookKeepsBothDomainsAndCanBeReloaded(t)
file=fullfile(t.TestData.Folder,"mixed.xlsx");
time=(0:19)';T=table(time,ones(20,1),4*ones(20,1),'VariableNames',{'Time [s]','Current [A]','Voltage [V]'});
frequency=logspace(3,-1,20)';z=.01+.02./(1+1i*2*pi*frequency);
E=table(frequency,real(z),imag(z),'VariableNames',{'Frequency [Hz]','Zreal [Ohm]','Zimag [Ohm]'});
writetable(T,file,'Sheet','pulse');writetable(E,file,'Sheet','impedance');
o=uecm.defaults();o.Circuit="RC";
input=uecm.Models.SessionModel.loadFile(file,o,"");
verifyEqual(t,numel(input.OriginalInputs),2);
verifyEqual(t,numel(unique(input.Files)),2);
for k=1:numel(input.Files)
    restored=uecm.readInput(input.Files(k));
    verifyEqual(t,restored.SourceFile,file);
    verifyEqual(t,height(restored.Data),20);
end
p=uecm.prepare(input);verifyEqual(t,p.Type,"mixed");
verifyEqual(t,sort(string(cellfun(@(q)q.Type,p.FilePrepared,'UniformOutput',false))),["EIS";"HPPC"]);
bundle=uecm.analyze(input);output=uecm.exportBundle(bundle,t.TestData.Folder);
catalog=readtable(fullfile(output,'input_file_catalog.csv'),'TextType','string','Delimiter',',','VariableNamingRule','preserve');
verifyEqual(t,height(catalog),2);verifyEqual(t,unique(catalog.source_file),file);
verifyEqual(t,sort(catalog.source_sheet),["impedance";"pulse"]);

end
function testMixedFolderRetainsRawTemplateAndFailureLog(t)
folder=t.TestData.Folder;mkdir(fullfile(folder,'nested'));
copyfile(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'),fullfile(folder,'eis.csv'));
file=fullfile(folder,'nested','raw.txt');
writelines(["Instrument export";"Time [s],Current [A],Voltage [V]";"0,0,4";"1,-1,3.99"],file);
writelines("Reference",fullfile(folder,'bad.txt'));
input=uecm.readFolder(folder);
verifyEqual(t,numel(input.Files),2);
verifyTrue(t,any(input.ImportLog.status=="unreadable"));
p=uecm.prepare(input);verifyEqual(t,p.Type,"mixed");
verifyTrue(t,isfield(input.OriginalInputs{2},'RawReport'));
end

function testFileBatchContinuesAfterAnUnreadableFile(t)
bad=fullfile(t.TestData.Folder,"bad.txt");writelines("reference only",bad);
good=fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv');
input=uecm.readInputs([bad;good]);
verifyEqual(t,numel(input.Files),1);
verifyTrue(t,any(input.ImportLog.status=="unreadable"));
verifyError(t,@()uecm.readInputs(bad),'uecm:Inputs');
end
