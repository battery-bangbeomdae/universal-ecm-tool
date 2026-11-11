% Real GUI integration: async import/fit/export/reopen/cancel, both input paths.
appRoot=fileparts(fileparts(mfilename('fullpath')));addpath(appRoot);
app=launch_universal_ecm();cleanup=onCleanup(@()delete(app.view));
app.view.loadExample("real");waitIdle(app,90);
assert(isfield(app.viewModel.Input,'Data'),app.viewModel.Status);
app.view.startAnalysis();waitIdle(app,120);
assert(height(app.viewModel.Bundle.Results)==12,app.viewModel.Status);
before=app.viewModel.Bundle.Results;
app.view.setAxes("soc_pct","temperature_C","Rct_Ohm");assert(isequaln(before,app.viewModel.Bundle.Results));
app.view.setAxes("soc_pct","temperature_C","Rs_Ohm");
app.view.saveScreenshot(fullfile(appRoot,'docs','real_eis_screen.png'));
parent=string(tempname);mkdir(parent);app.view.exportTo(parent);waitIdle(app,90);
folders=dir(fullfile(parent,'UniversalECM_*'));assert(numel(folders)==1);folder=fullfile(parent,folders(1).name);
assert(isfile(fullfile(folder,'session.mat')));assert(isfile(fullfile(folder,'estimated_parameters.csv')));
assert(isfile(fullfile(folder,'current_3D.png')),app.viewModel.Status);
app.view.loadSaved(fullfile(folder,'session.mat'));waitIdle(app,90);
assert(isequaln(app.viewModel.Bundle.Results,before),'Saved results not restored');
app.view.loadExample("hppc");waitIdle(app,90);app.view.startAnalysis();waitIdle(app,120);
assert(height(app.viewModel.Bundle.Results)==6,app.viewModel.Status);
app.view.setAxes("soc_pct","temperature_C","R0_Ohm");app.view.setSurface(true);
app.view.saveScreenshot(fullfile(appRoot,'docs','synthetic_hppc_screen.png'));
app.viewModel.selectFit(2); % selection listener renders voltage and residual.
app.view.loadExample("realhppc");waitIdle(app,90);app.view.startAnalysis();waitIdle(app,120);
assert(height(app.viewModel.Bundle.Results)==1,app.viewModel.Status);
assert(app.viewModel.Bundle.Results.fit_status=="review");assert(any(app.viewModel.Bundle.Prepared.Requests.Field=="soc"));
app.view.saveScreenshot(fullfile(appRoot,'docs','real_hppc_review_screen.png'));
app.view.loadExample("missing");waitIdle(app,90);
assert(any(app.viewModel.Bundle.Prepared.Requests.Field=="time"));
app.view.saveScreenshot(fullfile(appRoot,'docs','missing_data_screen.png'));
app.view.loadExample("eis");waitIdle(app,90);app.view.startAnalysis();app.view.stopAnalysis();waitIdle(app,90);
assert(contains(app.viewModel.Status,"취소"),app.viewModel.Status);assert(isempty(app.viewModel.Bundle.Results));
writelines(["UI smoke passed";"REAL EIS: 12 results";"REAL HPPC: 1 review result with SOC/request diagnostics"; ...
    "SYNTHETIC HPPC: 6 results and conditional surface";"Missing time: requested, no invented fit"; ...
    "Background import, fit, export and reopen completed";"Saved MAT/CSV/PNG/provenance verified"; ...
    "Axis change preserves fitted values";"Cancel does not publish a completed result"],fullfile(appRoot,'tests','ui_smoke_results.txt'));
clear cleanup
function waitIdle(app,seconds)
start=tic;
while app.viewModel.Busy&&toc(start)<seconds,drawnow;pause(.05);end
assert(~app.viewModel.Busy,'Background task timeout');drawnow;
end
