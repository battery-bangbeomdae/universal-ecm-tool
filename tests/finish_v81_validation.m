function finish_v81_validation()
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fullfile(root,'tests'));
out=fullfile(root,'merge_provenance','v8_1');
s=load(fullfile(out,'matlab_test_results.mat'),'r');r=s.r;
% The new renderer recreates axes; reacquire the handle after changing axes.
replacement=runtests('TestV81AxisVisibility','Name','*overlayNoneAuto2D');
assert(all([replacement.Passed]));
[found,location]=ismember(string({replacement.Name}),string({r.Name}));assert(all(found));r(location)=replacement;
disp(table(r));save(fullfile(out,'matlab_test_results.mat'),'r');
fid=fopen(fullfile(out,'test_summary.txt'),'w');fprintf(fid,'Passed: %d; Failed: %d; Incomplete: %d; Total: %d\n',sum([r.Passed]),sum([r.Failed]),sum([r.Incomplete]),numel(r));fclose(fid);
assert(all([r.Passed]),'v8.1 checks failed');
files=["+uecm/+Views/MainView.m","+uecm/+ViewModels/MainViewModel.m","+uecm/mapConditionNotice.m","+uecm/plotParameterFiles.m","+uecm/workspaceLoad.m"];
for file=files
 issues=checkcode(fullfile(root,file),'-id');assert(~any(strcmp({issues.id},'PARSE')));
end
% Render the real-data UI with no refitting on fabricated values.
o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
i=uecm.readInput(fullfile(root,'examples','REAL_D010_eis_12spectra.csv'),o);b=uecm.analyze(i);
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));a.viewModel.acceptInput(i);a.viewModel.acceptFit(b);
a.view.setAxes("soc_pct","none","Rs_Ohm");a.view.showStage("3d");drawnow;exportapp(a.view.UIFigure,fullfile(out,'real_data_2d.png'));
a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");drawnow;exportapp(a.view.UIFigure,fullfile(out,'real_data_3d.png'));
a.view.setOverlaySelection([1,2],true);a.view.setOverlayMode("응답·잔차");a.view.showStage("overlay");drawnow;exportapp(a.view.UIFigure,fullfile(out,'real_data_overlay.png'));
a.view.setFilePlotMode("combined");a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");drawnow;exportapp(a.view.UIFigure,fullfile(out,'real_data_combined.png'));
a.viewModel.acceptInput(uecm.readInputs([string(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'));string(fullfile(root,'examples','SYNTHETIC_2RC_eis_practice.csv'))],o,"") );
b=uecm.analyze(a.viewModel.Input);a.viewModel.acceptFit(b);a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");a.view.setFilePlotMode("combined");drawnow;exportapp(a.view.UIFigure,fullfile(out,'SYNTHETIC_two_files_combined.png'));
a.view.setFilePlotMode("split");drawnow;exportapp(a.view.UIFigure,fullfile(out,'SYNTHETIC_two_files_split.png'));
disp('V81_VALIDATION_COMPLETE');
end
