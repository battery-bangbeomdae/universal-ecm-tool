% User workflow: data -> actual fit history -> 1RC/2RC overlay -> ECM -> 3D.
appRootV02=fileparts(fileparts(mfilename('fullpath')));addpath(appRootV02);
appV02=launch_universal_ecm();cleanupV02=onCleanup(@()delete(appV02.view));appV02.view.UIFigure.Visible='off';
appV02.view.loadExample("hppc2");waitReadyV02(appV02,90);appV02.view.startAnalysis();waitReadyV02(appV02,120);
assert(height(appV02.viewModel.Bundle.Results)==4,appV02.viewModel.Status);
assert(all(appV02.viewModel.Bundle.Results.model=="2RC"));
appV02.viewModel.selectCandidate(2);
for stage=["process","comparison","circuit"]
    appV02.view.showStage(stage);drawnow;
    captureV02(appV02,fullfile(appRootV02,'docs',"v02_"+stage+".png"));
end
appV02.view.setMapModel("2RC");appV02.view.setAxes("soc_pct","temperature_C","R2_Ohm");appV02.view.setSurface(true);appV02.view.showStage("3d");
mapV02=findall(appV02.view.UIFigure,'Tag','ParameterMap');
assert(~isempty(findall(mapV02,'Type','patch')));appV02.view.setSurface(false);
assert(isempty(findall(mapV02,'Type','patch')),'Stale hidden surface survived model/plot change');appV02.view.setSurface(true);
captureV02(appV02,fullfile(appRootV02,'docs','v02_two_rc_3d.png'));
parentV02=string(tempname);mkdir(parentV02);appV02.view.exportTo(parentV02);waitReadyV02(appV02,120);
foldersV02=dir(fullfile(parentV02,'UniversalECM_*'));folderV02=fullfile(parentV02,foldersV02(1).name);
for name=["session.mat","all_model_comparison.csv","all_model_parameters.csv","selected_ECM.png","fitting_history.png","fit_0001_2RC_fitting_history.csv"]
    assert(isfile(fullfile(folderV02,name)),appV02.viewModel.Status);
end
beforeV02=appV02.viewModel.Bundle.Results;appV02.view.loadSaved(fullfile(folderV02,'session.mat'));waitReadyV02(appV02,90);
assert(isequaln(beforeV02,appV02.viewModel.Bundle.Results));assert(appV02.viewModel.SelectedCandidate==2);
% Recreate a v0.1-style session with ONE stored candidate and no iteration history.
legacyV02=appV02.viewModel.Bundle;oldV02=legacyV02.Fits{1}.Alternatives{1};
oldV02=rmfield(oldV02,{'ModelName','NParameters','BIC','History','StartSummary','BestStart'});
oldV02.CandidateScores=table("RC",1,'VariableNames',{'Circuit','BIC'});
legacyV02.Fits={oldV02};legacyV02.Results=struct2table(oldV02.Identity);legacyV02.Version="0.1.0";
legacyV02.Results=removevars(legacyV02.Results,{'model','R2_Ohm','C2_F','tau1_s','tau2_s'});
bundle=legacyV02;viewSettings=struct();legacyFileV02=fullfile(parentV02,'legacy_session.mat');save(legacyFileV02,'bundle','viewSettings','-v7');
appV02.view.loadSaved(legacyFileV02);waitReadyV02(appV02,90);assert(appV02.viewModel.Bundle.Version=="0.1.0");
appV02.view.showStage("circuit");
appV02.view.loadExample("real");waitReadyV02(appV02,90);appV02.view.startAnalysis();waitReadyV02(appV02,120);
assert(height(appV02.viewModel.Bundle.Results)==12,appV02.viewModel.Status);
appV02.view.showStage("3d");appV02.view.setAxes("soc_pct","temperature_C","Rs_Ohm");captureV02(appV02,fullfile(appRootV02,'docs','real_eis_screen.png'));
appV02.view.showStage("comparison");captureV02(appV02,fullfile(appRootV02,'docs','v02_real_eis_comparison.png'));
appV02.view.showStage("circuit");captureV02(appV02,fullfile(appRootV02,'docs','v02_real_eis_circuit.png'));
appV02.view.loadExample("missing");waitReadyV02(appV02,90);assert(any(appV02.viewModel.Bundle.Prepared.Requests.Field=="time"));captureV02(appV02,fullfile(appRootV02,'docs','missing_data_screen.png'));
appV02.view.loadExample("hppc2");waitReadyV02(appV02,90);appV02.view.startAnalysis();appV02.view.stopAnalysis();waitReadyV02(appV02,90);
assert(contains(appV02.viewModel.Status,'취소'));assert(isempty(appV02.viewModel.Bundle.Results));
writelines(["v0.2 GUI workflow passed";"Same-data 1RC/2RC overlays, metrics and real iteration traces displayed"; ...
    "1RC/2RC circuit diagrams and parameters rendered";"2RC parameter map and conditional surface rendered"; ...
    "All-model parameters/comparison/history/response CSV and ECM/history/raw PNG exported"; ...
    "Session reopen preserves candidate selection and fitted values";"v0.1-style session without alternatives/history renders successfully";"Real EIS 12-source spectrum comparisons rendered"; ...
    "Missing input and cancellation remain functional"],fullfile(appRootV02,'tests','ui_v02_results.txt'));
clear cleanupV02
function waitReadyV02(app,limit)
t=tic;while app.viewModel.Busy&&toc(t)<limit,drawnow;pause(.05);end
assert(~app.viewModel.Busy,'Background timeout');drawnow;
end

function captureV02(app,path)
app.view.UIFigure.Visible='on';drawnow;app.view.saveScreenshot(path);app.view.UIFigure.Visible='off';
end
