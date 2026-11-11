function tests=testCustomAxesDetail
tests=functiontests(localfunctions);
end
function [d,b]=fixture(domain)
file="/synthetic/input.csv";n=4;T=table((1:n)',repmat(domain,n,1),repmat(file,n,1),repmat("S",n,1),false(n,1),repmat("M",n,1),repmat("C",n,1),repmat("key",n,1), ...
 ["t1";"t2";"t3";"t4"],["s1";"s2";"s3";"s4"],[20;20;80;80],repmat(25,n,1),repmat(100,n,1),zeros(n,1),zeros(n,1), ...
 repmat(2,n,1),repmat(10,n,1),repmat("discharge",n,1),repmat(25,n,1),repmat(25,n,1),(11:14)', ...
 'VariableNames',{'curve_id','domain','source_file','source_id','synthetic','cell_model','cell_id','cell_key','test_id','measurement_id','soc_pct','temperature_C','soh_pct','cycle_number','calendar_days','pulse_amplitude_A','pulse_duration_s','pulse_direction','temperature_min_C','temperature_max_C','onset_source_row'});
s=struct('Domain',domain,'Frequency',[100;1],'Real',[.01;.02],'Imag',[-.01;-.02],'Time',[-1;0;1;2],'Voltage',[4;3.9;3.9;4],'DeltaVoltage',[0;-.1;-.1;0],'Current',[0;2;2;0],'Baseline',4,'SourceRows',(10:13)');
d=struct('Measurements',T,'Series',{repmat({s},n,1)},'Issues',strings(0,1),'FittingExecuted',false);
R=T(:,{'source_file','source_id','cell_id','test_id','domain'});R.spectrum_id=T.measurement_id;R.fit_id="F"+(1:n)';
fits=arrayfun(@(k)struct('SourceRows',(k+10:k+12)'),(1:n)','UniformOutput',false);b=struct('Results',R,'Fits',{fits});
M=table(R.fit_id,[25;50;25;50],'VariableNames',{'fit_id','storage_temperature_C'});b=uecm.addCustomAxis(b,M,"storage_temperature_C","저장 온도","°C","fit_id");
end
function testExactTraceIdentityAndMissingAndNoMutation(t)
[d,b]=fixture("EIS");before=d.Series;d.Measurements.source_file(4)="/other/input.csv";
a=uecm.attachCustomComparison(d,b);verifyEqual(t,a.Measurements.custom_storage_temperature_C,[25;50;25;NaN]);verifyEqual(t,a.Series,before);verifyFalse(t,a.FittingExecuted);
text=uecm.customConditionText(b,a.Measurements(2,:));verifyTrue(t,contains(text,'저장 온도 [°C]=50'));verifyEqual(t,a.Measurements.temperature_C,repmat(25,4,1));
end
function testHPPCRequiresSamePulseOnset(t)
[d,b]=fixture("HPPC");% Same test/spectrum, distinct pulses must keep distinct labels.
d.Measurements.test_id(:)="same";d.Measurements.measurement_id(:)="s";b.Results.test_id(:)="same";b.Results.spectrum_id(:)="s";
a=uecm.attachCustomComparison(d,b);verifyEqual(t,a.Measurements.custom_storage_temperature_C,[25;50;25;50]);
b.Fits{2}.SourceRows=[];a=uecm.attachCustomComparison(d,b);verifyTrue(t,isnan(a.Measurements.custom_storage_temperature_C(2)));verifyEqual(t,a.Measurements.custom_storage_temperature_C([1,3,4]),[25;25;50]);
end
function testDuplicateResultsNeverBroadcast(t)
[d,b]=fixture("EIS");b.Results=[b.Results;b.Results(1,:)];b.Fits=[b.Fits;b.Fits(1)];a=uecm.attachCustomComparison(d,b);verifyTrue(t,isnan(a.Measurements.custom_storage_temperature_C(1)));verifyEqual(t,a.Measurements.custom_storage_temperature_C(2),50);
end
function testDynamicConstraintsVariableAndUI(t)
[d,b]=fixture("EIS");a=uecm.attachCustomComparison(d,b);v=uecm.ViewModels.ConditionComparisonViewModel(a);v.setScope('CellKey','*');
v.preset("custom_storage_temperature_C");verifyEqual(t,height(v.Result.Table),2);verifyEqual(t,numel(unique(v.Result.Table.soc_pct)),1);
v.setConstraint("soc_pct",20,0,true);verifyEqual(t,v.Result.Table.custom_storage_temperature_C,[25;50]);
f=uecm.Views.ConditionComparisonView(v);c=onCleanup(@()delete(f)); %#ok<NASGU>
dd=findall(f.UIFigure,'Tag','ConditionVariable');verifyEqual(t,string(dd.Value),"custom_storage_temperature_C");verifyTrue(t,any(contains(string(dd.Items),'저장 온도 [°C]')));
v.preset("soc_pct");v.setConstraint("custom_storage_temperature_C",25,0,true);verifyEqual(t,v.Result.Table.soc_pct,[20;80]);
v.setConstraint("custom_storage_temperature_C",26,1,true);verifyEmpty(t,v.Result.Table);v.setToleranceEnabled(true);verifyEqual(t,height(v.Result.Table),2);
v.updateCustomConditions(struct());[fields,~]=v.variableChoices();verifyFalse(t,any(startsWith(fields,'custom_')));
end
function testMainDetailHeaderAndOpenComparisonUpdates(t)
root=fileparts(fileparts(mfilename('fullpath')));o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
i=uecm.readInput(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'),o);b=uecm.analyze(i);
a=launch_universal_ecm();c=onCleanup(@()delete(a.view)); %#ok<NASGU>
a.viewModel.acceptInput(i);a.viewModel.acceptFit(b);a.view.showConditionComparison();started=tic;
while a.viewModel.Busy&&toc(started)<45,drawnow;pause(.05);end
verifyFalse(t,a.viewModel.Busy);
M=table(b.Results.fit_id,25*ones(height(b.Results),1),'VariableNames',{'fit_id','storage_temperature_C'});
a.viewModel.importCustomAxis(M,"storage_temperature_C","저장 온도","°C","fit_id","test.csv");
a.view.showStage("comparison");header=findall(groot,'Tag','PrimaryConditions');verifyFalse(t,contains(string(header.Text),'추가 실험 조건:'));a.view.showMeasurementDetails("primary");full=findall(groot,'Tag','FullMeasurementMetadata');verifyTrue(t,contains(join(string(full.Value),newline),'추가 실험 조건: 저장 온도 [°C]=25'));
figs=findall(groot,'Tag','ConditionComparisonFigure');dd=findall(figs(1),'Tag','ConditionVariable');verifyTrue(t,ismember('custom_storage_temperature_C',dd.ItemsData));
verifyEqual(t,a.viewModel.Bundle.Results.Rs_Ohm,b.Results.Rs_Ohm);
end
