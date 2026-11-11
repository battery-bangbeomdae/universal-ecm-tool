% Fixture-only MATLAB-tool route. No LLM-curated or original study files used.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
outputFolder=fullfile(root,'output','recursive_import_ver5_verified_20261110','matlab_tool_fixture_validation');if ~isfolder(outputFolder),mkdir(outputFolder);end
r=string(tempname);mkdir(r);leaf=fullfile(r,'study','experiment','EIS');mkdir(leaf);
f=logspace(3,-1,16)';z=.01+.02./(1+1i*2*pi*f);T=table(f,real(z),imag(z),'VariableNames',{'frequency_hz','z_real_ohm','z_imag_ohm'});writetable(T,fullfile(leaf,'fixture.csv'));writelines("fixture readme",fullfile(r,'README.txt'));
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));a.view.loadSaved(r);t=tic;while a.viewModel.Busy&&toc(t)<90,drawnow;pause(.1);end
assert(~a.viewModel.Busy,a.viewModel.Status);assert(height(a.viewModel.Input.Data)==16,a.viewModel.Status);assert(isfield(a.viewModel.Input,'ImportLog'));assert(any(a.viewModel.Input.ImportLog.status=="loaded"));assert(any(a.viewModel.Input.ImportLog.status=="unreadable"));disp(a.viewModel.Status);a.view.showStage("inputs");a.view.saveScreenshot(fullfile(outputFolder,'parent_import_screen.png'));disp('BACKGROUND_PARENT_IMPORT_AUDIT_PROGRESS_PASS');clear cleanup;rmdir(r,'s');
