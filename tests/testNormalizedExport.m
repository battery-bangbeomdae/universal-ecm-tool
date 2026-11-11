function tests=testNormalizedExport
tests=functiontests(localfunctions);
end
function setup(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
t.TestData.Output=string(tempname);mkdir(t.TestData.Output);t.addTeardown(@()rmdir(t.TestData.Output,'s'));
end
function testEISRoundTripKeepsAllPointsAndConditions(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
i.Data.initial_capacity_Ah=repmat(5,height(i.Data),1);i.Data.current_capacity_Ah=repmat(4,height(i.Data),1);
p=uecm.prepare(i);dest=uecm.exportNormalized(i,t.TestData.Output);
[j,m]=reload(dest);q=uecm.prepare(j);
verifyFalse(t,q.Blocked);verifyEqual(t,q.Data.real,p.Data.real,'AbsTol',1e-14);
verifyEqual(t,q.Data.imag,p.Data.imag,'AbsTol',1e-14);verifyEqual(t,q.Data.frequency,p.Data.frequency);
verifyEqual(t,q.Data.soc,p.Data.soc);verifyEqual(t,q.Data.initial_capacity,p.Data.initial_capacity);
verifyEqual(t,q.Data.current_capacity,p.Data.current_capacity);verifyTrue(t,j.Synthetic);
verifyEqual(t,m.measurement_type,"EIS");verifyFalse(t,isfile(fullfile(dest,'_INCOMPLETE.txt')));
end
function testHPPCDischargeInternalToChargingExportAndVaryingSOC(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_hppc_practice.csv'));
i.Settings.CurrentSign="discharge_positive";
i.Data.soc_pct=linspace(80,70,height(i.Data))';i.Mapping.soc="soc_pct";
p=uecm.prepare(i);dest=uecm.exportNormalized(i,t.TestData.Output);[j,~]=reload(dest);q=uecm.prepare(j);
verifyFalse(t,q.Blocked);verifyEqual(t,q.Data.current,p.Data.current,'AbsTol',1e-12);
verifyEqual(t,q.Data.time,p.Data.time);verifyEqual(t,q.Data.voltage,p.Data.voltage);
verifyEqual(t,q.Data.soc,p.Data.soc,'AbsTol',1e-12);
verifyTrue(t,all(isnan(str2double(string(j.Metadata.soc_pct)))));verifyTrue(t,j.Synthetic);
end
function testPartialBatchLogsBlockedAndNewDirectory(t)
valid=uecm.readInput(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'));
bad=valid;bad.File=bad.File+"_bad";bad.Mapping.frequency="";
i=uecm.combineInputs({valid,bad},uecm.defaults());
a=uecm.exportNormalized(i,t.TestData.Output);b=uecm.exportNormalized(i,t.TestData.Output);
verifyNotEqual(t,a,b);log=readtable(fullfile(a,'export_log.csv'),'TextType','string','Delimiter',',');
verifyEqual(t,sum(log.status=="blocked"),1);verifyEqual(t,sum(log.status=="exported"),1);
m=readtable(fullfile(a,'manifest.csv'),'TextType','string','Delimiter',',');verifyEqual(t,height(m),1);
end
function testAllBlockedDoesNotWriteOutput(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'));i.Mapping.frequency="";
verifyError(t,@()uecm.exportNormalized(i,t.TestData.Output),'uecm:ExportBlocked');
a=dir(t.TestData.Output);verifyEqual(t,sum(~ismember(string({a.name}),[".",".."])),0);
end
function testUIHasPrefitExportButton(t)
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));
b=findall(a.view.UIFigure,'Text','정제 데이터 CSV 저장');verifyNumElements(t,b,1);
a.view.exportNormalizedTo(t.TestData.Output);verifyFalse(t,a.viewModel.Busy);
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
a.viewModel.acceptInput(i);a.view.exportNormalizedTo(t.TestData.Output);
timer=tic;
while a.viewModel.Busy&&toc(timer)<60,drawnow;pause(.1);end
verifyFalse(t,a.viewModel.Busy);verifyTrue(t,contains(a.viewModel.Status,"표준 CSV 저장 완료"));
d=dir(fullfile(t.TestData.Output,'ECM_standard_*'));verifyNumElements(t,d,1);
verifyTrue(t,isfile(fullfile(d(1).folder,d(1).name,'manifest.csv')));
end
function [i,m]=reload(dest)
m=readtable(fullfile(dest,'manifest.csv'),'TextType','string','Delimiter',',');
o=uecm.defaults();o.ImportMode="template";o.Type=m.measurement_type(1);o.CurrentSign="charge_positive";
i=uecm.readInput(fullfile(dest,m.signal_file(1)),o,fullfile(dest,m.conditions_file(1)));
end
