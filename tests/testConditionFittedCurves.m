function tests=testConditionFittedCurves
tests=functiontests(localfunctions);
end
function [d,b]=fixture(domain)
T=table([1;2],repmat(domain,2,1),repmat("/input.csv",2,1),repmat("S",2,1),false(2,1),repmat("M",2,1),repmat("C",2,1),repmat("key",2,1), ...
 ["t1";"t2"],["s1";"s2"],[20;80],[25;25],[100;100],[0;0],[0;0],[2;2],[10;10],["discharge";"discharge"],[25;25],[25;25],[11;31], ...
 'VariableNames',{'curve_id','domain','source_file','source_id','synthetic','cell_model','cell_id','cell_key','test_id','measurement_id','soc_pct','temperature_C','soh_pct','cycle_number','calendar_days','pulse_amplitude_A','pulse_duration_s','pulse_direction','temperature_min_C','temperature_max_C','onset_source_row'});
s=struct('Domain',domain,'Frequency',[100;10;1],'Real',[.01;.02;.03],'Imag',[-.01;-.02;-.03], ...
 'Time',[-1;0;1;2],'Voltage',[4;3.9;3.9;4],'DeltaVoltage',[0;-.1;-.1;0],'Current',[0;2;2;0],'Baseline',4,'SourceRows',(10:13)');
d=struct('Measurements',T,'Series',{{s;s}},'Issues',strings(0,1),'FittingExecuted',false);
R=T(:,{'source_file','source_id','cell_id','test_id','domain'});R.spectrum_id=T.measurement_id;R.fit_id=["F1";"F2"];
c=struct('Domain',domain,'ModelName',"1RC",'Predicted',[.011-.01i;.021-.02i;.031-.03i],'Frequency',[100;10;1], ...
 'Time',[0;1;2],'Measured',[.01-.01i;.02-.02i;.03-.03i],'Baseline',4,'RMSE',.001,'ErrorUnit',"Ohm",'Status',"candidate",'Parameters',struct('R0_Ohm',.01),'SourceRows',(11:13)');
if domain=="HPPC",c.Predicted=[3.91;3.92;3.99];c.Measured=[3.9;3.9;4];c.ErrorUnit="V";end
c2=c;c2.ModelName="2RC";c2.Status="review";f=c;f.Alternatives={c,c2};f.RecommendedIndex=2;f2=f;f2.SourceRows=(31:33)';
b=struct('Results',R,'Fits',{{f;f2}});d=uecm.attachFittedComparison(d,b);
end
function testExactModelNoFallbackAndOriginalValues(t)
[d,b]=fixture("EIS");c=uecm.comparisonCandidate(d,1,"2RC");verifyEqual(t,c.Predicted,b.Fits{1}.Alternatives{2}.Predicted);verifyEqual(t,c.Parameters,b.Fits{1}.Alternatives{2}.Parameters);verifyEmpty(t,uecm.comparisonCandidate(d,1,"CPE"));
verifyEqual(t,uecm.comparisonCandidate(d,1,"권장 모델").ModelName,"2RC");verifyFalse(t,d.FittingExecuted);
b.Results.source_file(2)="other";a=uecm.attachFittedComparison(d,b);verifyEmpty(t,a.FitCandidates{2});verifyEqual(t,a.Series,d.Series);
end
function testHPPCOnsetSpecific(t)
[d,b]=fixture("HPPC");d.Measurements.test_id(:)="same";d.Measurements.measurement_id(:)="s";b.Results.test_id(:)="same";b.Results.spectrum_id(:)="s";
a=uecm.attachFittedComparison(d,b);verifyNotEmpty(t,a.FitCandidates{2});b.Fits{2}.SourceRows=(41:43)';a=uecm.attachFittedComparison(d,b);verifyEmpty(t,a.FitCandidates{2});
end
function testEISOverlayModelFilterAndSplit(t)
[d,~]=fixture("EIS");v=uecm.ViewModels.ConditionComparisonViewModel(d);a=uecm.Views.ConditionComparisonView(v);cleanup=onCleanup(@()delete(a)); %#ok<NASGU>
v.setFitDisplay("2RC","both");lines=findall(a.UIFigure,'Tag','ConditionFittedCurve');verifyEqual(t,numel(lines),2);verifyEqual(t,sort(lines(1).XData),[11,21,31],'AbsTol',1e-10);
verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionMeasuredCurve')),2);
v.setFitDisplay("2RC","fit");verifyEmpty(t,findall(a.UIFigure,'Tag','ConditionMeasuredCurve'));verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionFittedCurve')),2);
f=findall(a.UIFigure,'Tag','ConditionFrequency');f.Value='band';feval(f.ValueChangedFcn,f,[]);lines=findall(a.UIFigure,'Tag','ConditionFittedCurve');verifyEqual(t,numel(lines(1).XData),3);
m=findall(a.UIFigure,'Tag','ConditionPlotMode');m.Value='split';feval(m.ValueChangedFcn,m,[]);verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionResponseAxes')),2);
v.setFitDisplay("CPE","both");verifyEmpty(t,findall(a.UIFigure,'Tag','ConditionFittedCurve'));verifyEqual(t,numel(findall(a.UIFigure,'Tag','ConditionMeasuredCurve')),2);
end
function testHPPCDeltaAndVoltageAndExport(t)
[d,~]=fixture("HPPC");v=uecm.ViewModels.ConditionComparisonViewModel(d);a=uecm.Views.ConditionComparisonView(v);cleanup=onCleanup(@()delete(a)); %#ok<NASGU>
v.setFitDisplay("1RC","both");lines=findall(a.UIFigure,'Tag','ConditionFittedCurve');verifyEqual(t,lines(1).XData,[0,1,2]);verifyEqual(t,lines(1).YData,[-90,-80,-10],'AbsTol',1e-9);
r=findall(a.UIFigure,'Tag','ConditionPulseResponse');r.Value='voltage';feval(r.ValueChangedFcn,r,[]);lines=findall(a.UIFigure,'Tag','ConditionFittedCurve');verifyEqual(t,lines(1).YData,[3.91,3.92,3.99]);
[P,C]=uecm.comparisonFitExport(d,v.Result.Table,"1RC");verifyTrue(t,all(P.fit_available));verifyEqual(t,height(C),6);verifyEqual(t,P.parameter_R0_Ohm,[.01;.01]);verifyEqual(t,C.delta_voltage_V(1:3),[-.09;-.08;-.01],'AbsTol',1e-12);
end
