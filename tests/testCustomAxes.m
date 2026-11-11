function tests=testCustomAxes
tests=functiontests(localfunctions);
end
function b=fixture()
R=table(["F1";"F2";"F3"],["C1";"C1";"C2"],["T1";"T2";"T1"],[25;25;25],[20;80;20],[.01;.02;.03], ...
 'VariableNames',{'fit_id','cell_id','test_id','temperature_C','soc_pct','Rs_Ohm'});
b=struct('Results',R,'Fits',{{}});
end
function testJoinPreservesMeasuredValuesAndMissing(t)
b=fixture();M=table(["C2";"C1"],["T1";"T1"],[50;25],'VariableNames',{'cell_id','test_id','storage_temperature_C'});
[b,msg]=uecm.addCustomAxis(b,M,"storage_temperature_C","저장 온도","°C",["cell_id","test_id"]);
verifyEqual(t,b.Results.temperature_C,[25;25;25]);verifyEqual(t,b.Results.custom_storage_temperature_C,[25;NaN;50]);verifyTrue(t,contains(msg,'2 / 3'));
verifyEqual(t,b.CustomAxes.Unit,"°C");verifyEqual(t,b.CustomAxes.Keys,["cell_id","test_id"]);
end
function testAmbiguousDuplicateAndBadNumbersFail(t)
b=fixture();M=table(["C1";"C1"],[20;80],'VariableNames',{'cell_id','storage_soc'});
verifyError(t,@()uecm.addCustomAxis(b,M,"storage_soc","SOC","%","cell_id"),'uecm:CustomAxis');
M=table(["F1";"F2"],["20";"unknown"],'VariableNames',{'fit_id','storage_soc'});
verifyError(t,@()uecm.addCustomAxis(b,M,"storage_soc","SOC","%","fit_id"),'uecm:CustomAxis');
M.storage_soc=["20";""];b=uecm.addCustomAxis(b,M,"storage_soc","SOC","%","fit_id");verifyEqual(t,b.Results.custom_storage_soc,[20;NaN;NaN]);
verifyError(t,@()uecm.addCustomAxis(b,M,"storage_soc","SOC","%","fit_id"),'uecm:CustomAxis');
end
function testNoMatchAndEmptyKeyFail(t)
b=fixture();M=table("other",50,'VariableNames',{'fit_id','dose'});
verifyError(t,@()uecm.addCustomAxis(b,M,"dose","Dose","","fit_id"),'uecm:CustomAxis');
M.fit_id="";verifyError(t,@()uecm.addCustomAxis(b,M,"dose","Dose","","fit_id"),'uecm:CustomAxis');
end
function testVMChoicesFilterAndSession(t)
b=fixture();M=table(["C1";"C2"],[25;50],'VariableNames',{'cell_id','storage_temperature_C'});
model=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(model);model.Bundle=b;
v.importCustomAxis(M,"storage_temperature_C","저장 온도","°C","cell_id","test.csv");
[fields,labels]=v.axisChoices();verifyEqual(t,fields(end),"custom_storage_temperature_C");verifyEqual(t,labels(end),"저장 온도 [°C]");
f=struct('Numeric',table("custom_storage_temperature_C",true,25,25,'VariableNames',{'field','enabled','minimum','maximum'}));
[k,~]=uecm.filterMapConditions(v.Bundle.Results,f,["soc_pct","temperature_C"]);verifyEqual(t,k,[true;true;false]);
[k,~]=uecm.filterMapConditions(v.Bundle.Results,f,["custom_storage_temperature_C","temperature_C"]);verifyTrue(t,all(k));
a=uecm.Views.MapConditionFilterView(v,"soc_pct","temperature_C");cleanup=onCleanup(@()delete(a)); %#ok<NASGU>
T=findall(a.UIFigure,'Tag','MapConditionRanges');verifyEqual(t,height(T.Data),5);verifyEqual(t,T.Data.condition(end),"저장 온도 [°C]");
file=string(tempname)+".mat";c=onCleanup(@()delete(file));bundle=v.Bundle;save(file,'bundle');s=load(file);verifyEqual(t,s.bundle.CustomAxes,v.Bundle.CustomAxes); %#ok<NASGU>
end
function testMainButtons(t)
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view)); %#ok<NASGU>
verifyNotEmpty(t,findall(a.view.UIFigure,'Tag','CustomAxisImport'));verifyNotEmpty(t,findall(a.view.UIFigure,'Tag','CustomAxisTemplate'));
end
function testExportDictionaryAndValues(t)
b=fixture();M=table(["C1";"C2"],[20;80],'VariableNames',{'cell_id','storage_soc'});b=uecm.addCustomAxis(b,M,"storage_soc","저장 SOC","%","cell_id");
root=fileparts(fileparts(mfilename('fullpath')));i=uecm.readInput(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'));b.Prepared=uecm.prepare(i);b.Version="test";b.Timestamp="test";
folder=string(tempname);mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
out=uecm.exportBundle(b,folder);D=readtable(fullfile(out,'custom_axis_definitions.csv'),'TextType','string');verifyEqual(t,D.Label,"저장 SOC");
R=readtable(fullfile(out,'estimated_parameters.csv'));verifyEqual(t,R.custom_storage_soc,[20;20;80]);
end

function testMainAxisSelectionAfterImport(t)
root=fileparts(fileparts(mfilename('fullpath')));o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
i=uecm.readInput(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'),o);b=uecm.analyze(i);
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view)); %#ok<NASGU>
a.viewModel.acceptInput(i);a.viewModel.acceptFit(b);
M=table(b.Results.fit_id,(1:height(b.Results))','VariableNames',{'fit_id','exposure_days'});
a.viewModel.importCustomAxis(M,"exposure_days","노출 경과일","day","fit_id","test.csv");
x=findall(a.view.UIFigure,'Tag','XAxisChoice');verifyTrue(t,ismember('custom_exposure_days',x.ItemsData));
a.view.setAxes("custom_exposure_days","temperature_C","Rs_Ohm");verifyEqual(t,string(x.Value),"custom_exposure_days");
verifyEqual(t,a.viewModel.Bundle.Results.Rs_Ohm,b.Results.Rs_Ohm);
end
