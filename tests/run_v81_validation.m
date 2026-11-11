function run_v81_validation()
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fullfile(root,'tests'));
out=fullfile(root,'merge_provenance','v8_1');
files={'TestV81FilePlots','TestV81AxisVisibility','testCustomAxes','testCalendarAxis','testCore'};
r=runtests(files);disp(table(r));save(fullfile(out,'matlab_test_results.mat'),'r');
fid=fopen(fullfile(out,'test_summary.txt'),'w');fprintf(fid,'Passed: %d; Failed: %d; Incomplete: %d; Total: %d\n',sum([r.Passed]),sum([r.Failed]),sum([r.Incomplete]),numel(r));fclose(fid);
assert(all([r.Passed]),'v8.1 regression checks failed');
% Render the real-data UI with no refitting on fabricated values.
o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
i=uecm.readInput(fullfile(root,'examples','REAL_D010_eis_12spectra.csv'),o);b=uecm.analyze(i);
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));a.viewModel.acceptInput(i);a.viewModel.acceptFit(b);
a.view.setAxes("soc_pct","none","Rs_Ohm");a.view.showStage("3d");drawnow;exportapp(a.view.UIFigure,fullfile(out,'real_data_2d.png'));
a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");drawnow;exportapp(a.view.UIFigure,fullfile(out,'real_data_3d.png'));
a.view.setOverlaySelection([1,2],true);a.view.setOverlayMode("응답·잔차");a.view.showStage("overlay");drawnow;exportapp(a.view.UIFigure,fullfile(out,'real_data_overlay.png'));
a.view.setFilePlotMode("combined");a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");drawnow;exportapp(a.view.UIFigure,fullfile(out,'real_data_combined.png'));
disp('V81_VALIDATION_COMPLETE');
end
