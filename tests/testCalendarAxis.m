function tests=testCalendarAxis
tests=functiontests(localfunctions);
end
function setup(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
t.TestData.Dir=string(tempname);mkdir(t.TestData.Dir);t.addTeardown(@()rmdir(t.TestData.Dir,'s'));
end
function testExplicitUnitsAreSeparateFromSignalTime(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
i.Data.aging_hours=repmat(240,height(i.Data),1);i.Mapping=uecm.inferMapping(i.Data.Properties.VariableNames);
p=uecm.prepare(i);verifyEqual(t,p.Data.calendar,repmat(10,height(i.Data),1));verifyEqual(t,p.Type,"EIS");
verifyEqual(t,uecm.calendarData(table(2.5,'VariableNames',{'calendar_weeks'}),"calendar_weeks"),17.5);
verifyEqual(t,uecm.inferMapping(["time_s","cycle_number"]).calendar,"");
end
function testRawImportPreservesCalendarColumn(t)
f=fullfile(t.TestData.Dir,'raw.csv');writelines(["frequency_hz,z_real_ohm,z_imag_ohm,aging_hours";"10,0.01,-0.01,240";"1,0.02,-0.01,240"],f);
o=uecm.defaults();o.ImportMode="raw";i=uecm.readInput(f,o);p=uecm.prepare(i);
verifyFalse(t,p.Blocked);verifyEqual(t,p.Data.calendar,[10;10]);verifyEqual(t,p.Type,"EIS");
end
function testMetadataJoinAndFitCarryDays(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'));
i.Settings.EISModels="RC";i.Settings.EISAutoWarburg=false;
keys=unique(i.Data(:,{'source_id','cell_id','test_id','spectrum_id'}),'rows','stable');
keys.calendar_days=repmat(365.5,height(keys),1);i.Metadata=keys;
p=uecm.prepare(i);verifyEqual(t,p.Data.calendar,repmat(365.5,height(i.Data),1));
verifyTrue(t,all(p.Data.calendar_source=="metadata"));b=uecm.analyze(i);
verifyEqual(t,b.Results.calendar_days,repmat(365.5,height(b.Results),1));
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));a.viewModel.acceptInput(i);a.viewModel.acceptFit(b);
x=findall(a.view.UIFigure,'Tag','XAxisChoice');verifyTrue(t,ismember('calendar_days',x.ItemsData));
a.view.setAxes("calendar_days","soc_pct","Rs_Ohm");
[R,~,~]=a.viewModel.chartData("calendar_days","soc_pct","Rs_Ohm","모두 (점으로 비교)","모두","권장 모델");
verifyEqual(t,height(R),height(b.Results));
end
function testManualDaysAndExportRoundTrip(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));a.viewModel.acceptInput(i);a.viewModel.diagnose();
b=findall(findall(groot,'Tag','InputInformationWindow'),'Text','조건 다시 확인');feval(b.ButtonPushedFcn,b,[]);
grid=findall(findall(groot,'Tag','InputInformationWindow'),'Tag','MeasurementConditions');
feval(grid.CellEditCallback,grid,struct('Indices',[1,12],'NewData',28.5));
verifyEqual(t,grid.Data.calendar_days(1),28.5);verifyEqual(t,grid.Data.calendar_source(1),"manual");
i=a.viewModel.analysisInput();dest=uecm.exportNormalized(i,t.TestData.Dir);
m=readtable(fullfile(dest,'manifest.csv'),'Delimiter',',','TextType','string');o=uecm.defaults();o.ImportMode="template";
j=uecm.readInput(fullfile(dest,m.signal_file(1)),o,fullfile(dest,m.conditions_file(1)));p=uecm.prepare(j);
verifyTrue(t,any(p.Data.calendar==28.5));verifyTrue(t,any(isnan(p.Data.calendar)));
verifyError(t,@()uecm.validateConditionValue("calendar_days",-1),'uecm:ConditionValue');
end
