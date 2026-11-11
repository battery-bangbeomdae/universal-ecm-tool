function tests=testConditionComparison
tests=functiontests(localfunctions);
end
function setup(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);t.TestData.Temp=string(tempname);mkdir(t.TestData.Temp);t.addTeardown(@()rmdir(t.TestData.Temp,'s'));
end
function i=eisInput(t,name)
if nargin<2,name="eis";end
rows={};
for cell=["C1","C2"]
 for soc=[20,50,80]
  for temp=[15,25]
   for soh=[90,100]
    id=cell+"_"+soc+"_"+temp+"_"+soh;
    for f=[1000,10,1]
     rows{end+1,1}=struct('source_id',"S",'cell_id',cell,'test_id',id,'spectrum_id',id,'frequency_hz',f,'z_real_ohm',.02+.01/(1+f), ...
      'z_imag_ohm',-.01/(1+f),'soc_pct',soc,'temperature_C',temp,'soh_pct',soh,'cycle_number',100-soh,'calendar_days',100-soh,'cell_model',"ModelA"); %#ok<AGROW>
    end
   end
  end
 end
end
file=fullfile(t.TestData.Temp,name+".csv");writetable(struct2table(vertcat(rows{:})),file);o=uecm.defaults();o.ImportMode="template";o.Type="EIS";i=uecm.readInput(file,o);
end
function i=pulseInput(t)
rows={};
for soc=[20,80]
 time=(0:40)';current=zeros(size(time));active=time>=10&time<=20;current(active)=-2;voltage=4+.05*current;
 id="pulse_"+soc;
 for k=1:numel(time)
  rows{end+1,1}=struct('source_id',"H",'cell_id',"H1",'test_id',id,'spectrum_id',id,'time_s',time(k),'current_A',current(k),'voltage_V',voltage(k), ...
   'soc_pct',soc,'temperature_C',25,'soh_pct',100,'cycle_number',0,'calendar_days',0,'cell_model',"PulseModel"); %#ok<AGROW>
 end
end
file=fullfile(t.TestData.Temp,'hppc.csv');writetable(struct2table(vertcat(rows{:})),file);o=uecm.defaults();o.ImportMode="template";o.Type="HPPC";o.CurrentSign="charge_positive";i=uecm.readInput(file,o);
end
function testExactAndExplicitTolerance(t)
d=uecm.conditionComparisonData(uecm.prepare(eisInput(t)));v=uecm.ViewModels.ConditionComparisonViewModel(d);
verifyEqual(t,height(d.Measurements),24);verifyFalse(t,d.FittingExecuted);verifyEqual(t,height(v.Result.Table),3);verifyEqual(t,nnz(v.Selected),3);
v.setConstraint("temperature_C",26,1,true);verifyEmpty(t,v.Result.Table);v.setToleranceEnabled(true);verifyEqual(t,height(v.Result.Table),3);verifyTrue(t,all(v.Result.Table.temperature_C==25));
end
function testMissingAndVaryingConditionsNeverBecomeFixed(t)
i=eisInput(t);i.Data.soh_pct(:)=NaN;d=uecm.conditionComparisonData(uecm.prepare(i));v=uecm.ViewModels.ConditionComparisonViewModel(d);
verifyEqual(t,height(v.Result.Table),3);verifyEqual(t,v.Fixed.temperature_C,25);verifyTrue(t,all(isnan(v.Result.Table.soh_pct)));verifyTrue(t,contains(v.Result.Message,'soh_pct 미기록'));
v.preset("soh_pct");verifyEmpty(t,v.Result.Table);
i=eisInput(t,"vary");i.Data.temperature_C(1)=26;d=uecm.conditionComparisonData(uecm.prepare(i));verifyTrue(t,any(isnan(d.Measurements.temperature_C)));
end
function testIdentityIncludesInputFile(t)
i1=eisInput(t,"one");i2=eisInput(t,"two");o=i1.Settings;i=uecm.readInputs([i1.File;i2.File],o);d=uecm.conditionComparisonData(uecm.prepare(i));
verifyEqual(t,height(d.Measurements),48);verifyEqual(t,numel(unique(d.Measurements.cell_key)),4);
end
function testPulseAlignmentBaselineAndNoFitting(t)
i=pulseInput(t);d=uecm.conditionComparisonData(uecm.prepare(i));verifyEqual(t,height(d.Measurements),2);
s=d.Series{1};verifyEqual(t,s.Time(find(s.Current>1,1)),0);verifyEqual(t,s.Baseline,4);verifyEqual(t,s.DeltaVoltage(find(s.Time==0)),-.1,'AbsTol',1e-12);verifyEqual(t,s.Current(find(s.Time==0)),2);
verifyEqual(t,d.Measurements.pulse_duration_s,[10;10]);verifyTrue(t,all(d.Measurements.pulse_direction=="discharge"));
v=uecm.ViewModels.ConditionComparisonViewModel(d);verifyEqual(t,height(v.Result.Table),2);v.setScope('Direction','charge');verifyEmpty(t,v.Result.Table);
end
function testMixedInputKindsStaySeparate(t)
a=eisInput(t);b=pulseInput(t);o=uecm.defaults();o.Type="auto";o.ImportMode="template";o.CurrentSign="charge_positive";
d=uecm.conditionComparisonData(uecm.prepare(uecm.readInputs([a.File;b.File],o)));verifyEqual(t,height(d.Measurements),26);
v=uecm.ViewModels.ConditionComparisonViewModel(d);v.setScope('Domain','HPPC');verifyEqual(t,height(v.Result.Table),2);verifyTrue(t,all(v.Result.Table.domain=="HPPC"));
end
function testEISControlsAndScrollableSplit(t)
d=uecm.conditionComparisonData(uecm.prepare(eisInput(t)));v=uecm.ViewModels.ConditionComparisonViewModel(d);a=uecm.Views.ConditionComparisonView(v);c=onCleanup(@()delete(a)); %#ok<NASGU>
verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionResponseAxes')),1);
f=findall(a.UIFigure,'Tag','ConditionFrequency');f.Value='band';feval(f.ValueChangedFcn,f,[]);
ax=findall(a.UIFigure,'Tag','ConditionResponseAxes');lines=findall(ax,'Type','line','-not','Tag',''); %#ok<NASGU>
m=findall(a.UIFigure,'Tag','ConditionPlotMode');m.Value='split';feval(m.ValueChangedFcn,m,[]);
verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionResponseAxes')),3);g=findall(a.UIFigure,'Tag','ConditionPlotGrid');verifyEqual(t,string(g.Scrollable),"on");verifyEqual(t,g.RowHeight,{520,520,520});
v.setSelected([],false);verifyEqual(t,nnz(v.Selected),0);
end
function testHPPCVoltageAndCurrentUI(t)
d=uecm.conditionComparisonData(uecm.prepare(pulseInput(t)));v=uecm.ViewModels.ConditionComparisonViewModel(d);a=uecm.Views.ConditionComparisonView(v);c=onCleanup(@()delete(a)); %#ok<NASGU>
verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionResponseAxes')),1);verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionCurrentAxes')),1);
ax=findall(a.UIFigure,'Tag','ConditionResponseAxes');verifyLessThan(t,ax.XLim(1),0);verifyGreaterThan(t,ax.XLim(2),10);
r=findall(a.UIFigure,'Tag','ConditionPulseResponse');r.Value='voltage';feval(r.ValueChangedFcn,r,[]);ax=findall(a.UIFigure,'Tag','ConditionResponseAxes');verifyEqual(t,string(ax.YLabel.String),"전압 [V]");
m=findall(a.UIFigure,'Tag','ConditionPlotMode');m.Value='split';feval(m.ValueChangedFcn,m,[]);verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionCurrentAxes')),2);
end
function testMapConditionRangesDoNotAverageOrConstrainAxis(t)
R=table([20;20;50],[25;25;25],[100;90;100],[.01;.02;.03],repmat("M",3,1),["C1";"C2";"C1"], ...
 'VariableNames',{'soc_pct','temperature_C','soh_pct','Rs_Ohm','cell_model','cell_id'});
f=struct('Numeric',table("soh_pct",true,100,100,'VariableNames',{'field','enabled','minimum','maximum'}));
[k,n]=uecm.filterMapConditions(R,f,["soc_pct","temperature_C"]);verifyEqual(t,k,[true;false;true]);verifyTrue(t,contains(n,'soh_pct'));
[k,~]=uecm.filterMapConditions(R,f,["soh_pct","temperature_C"]);verifyTrue(t,all(k));verifyTrue(t,contains(uecm.mapConditionNotice(R,"soc_pct","temperature_C"),'추가 1점'));
R.soh_pct(1)=NaN;[k,~]=uecm.filterMapConditions(R,f,["soc_pct","temperature_C"]);verifyEqual(t,k,[false;false;true]);
f.Numeric.minimum=101;f.Numeric.maximum=100;verifyError(t,@()uecm.filterMapConditions(R,f), 'uecm:MapFilter');
end
function testMainViewMapFilterAndComparisonEntry(t)
a=launch_universal_ecm();c=onCleanup(@()delete(a.view)); %#ok<NASGU>
verifyNotEmpty(t,findall(a.view.UIFigure,'Tag','MapConditionFilterButton'));verifyNotEmpty(t,findall(a.view.UIFigure,'Text','조건별 EIS · HPPC 비교'));
i=eisInput(t);a.viewModel.acceptInput(i);a.viewModel.diagnose();a.view.showConditionComparison();started=tic;
while a.viewModel.Busy&&toc(started)<45,drawnow;pause(.05);end
verifyFalse(t,a.viewModel.Busy);verifyNotEmpty(t,findall(groot,'Tag','ConditionComparisonFigure'));verifyEmpty(t,a.viewModel.Bundle.Results);
end
function testMapFilterAppliesToDisplayedResultsAndResetsForNewInput(t)
model=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(model);file=fullfile(t.TestData.Temp,'results.csv');v.SelectedFile=file;
R=table(["f1";"f2";"f3"],repmat(file,3,1),repmat("S",3,1),["C1";"C2";"C1"],repmat("M",3,1),repmat("EIS",3,1), ...
 [20;20;50],[25;25;25],[100;90;100],[0;10;0],[0;10;0],[.01;.02;.03],repmat("candidate",3,1), ...
 'VariableNames',{'fit_id','source_file','source_id','cell_id','cell_model','domain','soc_pct','temperature_C','soh_pct','cycle_number','calendar_days','Rs_Ohm','fit_status'});
fits=arrayfun(@(~)struct('SourceFile',file),(1:3)','UniformOutput',false);model.Bundle=struct('Results',R,'Fits',{fits});
f=uecm.Views.MapConditionFilterView(v,"soc_pct","temperature_C");c=onCleanup(@()delete(f)); %#ok<NASGU>
T=findall(f.UIFigure,'Tag','MapConditionRanges');rows=T.Data;rows.enabled(3)=true;rows.minimum(3)=100;rows.maximum(3)=100;T.Data=rows;
b=findall(f.UIFigure,'Tag','MapFilterApply');feval(b.ButtonPushedFcn,b,[]);
[points,indices,~]=v.chartData("soc_pct","temperature_C","Rs_Ohm","모두 (점으로 비교)","모두 (주의 포함)");verifyEqual(t,indices,[1;3]);verifyEqual(t,points.Rs_Ohm,[.01;.03]);
[points,~,~]=v.chartData("soh_pct","temperature_C","Rs_Ohm","모두 (점으로 비교)","모두 (주의 포함)");verifyEqual(t,height(points),3);
v.acceptInput(eisInput(t));verifyEmpty(t,fieldnames(v.MapFilters));
end
function testAgeingPresetDoesNotFreezeCorrelatedCycle(t)
d=uecm.conditionComparisonData(uecm.prepare(eisInput(t)));v=uecm.ViewModels.ConditionComparisonViewModel(d);v.preset("soh_pct");
verifyEqual(t,height(v.Result.Table),2);verifyEqual(t,numel(unique(v.Result.Table.soc_pct)),1);verifyEqual(t,v.Fixed.temperature_C,25);verifyTrue(t,isnan(v.Fixed.cycle_number));verifyTrue(t,isnan(v.Fixed.calendar_days));
v.preset("cycle_number");verifyEqual(t,height(v.Result.Table),2);verifyTrue(t,isnan(v.Fixed.soh_pct));
end
function testSyntheticSourceRemainsLabelled(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
d=uecm.conditionComparisonData(uecm.prepare(i));verifyTrue(t,all(d.Measurements.synthetic));
v=uecm.ViewModels.ConditionComparisonViewModel(d);a=uecm.Views.ConditionComparisonView(v);c=onCleanup(@()delete(a)); %#ok<NASGU>
l=findall(a.UIFigure,'Tag','ConditionComparisonSummary');verifyTrue(t,contains(string(l.Text),'가상 연습'));
end
function testExplicitAllCellsIsNotSilentlyReset(t)
d=uecm.conditionComparisonData(uecm.prepare(eisInput(t)));v=uecm.ViewModels.ConditionComparisonViewModel(d);v.setScope('CellKey','*');
verifyEqual(t,v.CellKey,"*");verifyEqual(t,height(v.Result.Table),6);verifyTrue(t,any(contains(v.Result.Warnings,'여러 물리 셀')));
v.preset("cell_id");verifyEqual(t,height(v.Result.Table),2);
end
