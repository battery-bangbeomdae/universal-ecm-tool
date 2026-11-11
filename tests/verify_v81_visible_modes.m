function verify_v81_visible_modes()
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);out=fullfile(root,'merge_provenance','v8_1');
o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
i=uecm.readInputs([string(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'));string(fullfile(root,'examples','SYNTHETIC_2RC_eis_practice.csv'))],o,"");b=uecm.analyze(i);
a=launch_universal_ecm();c=onCleanup(@()delete(a.view));a.view.UIFigure.WindowState='normal';a.view.UIFigure.Position=[40,40,1600,900];drawnow;
a.viewModel.acceptInput(i);a.viewModel.acceptFit(b);a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");
a.view.setFilePlotMode("combined");drawnow;pause(1);drawnow;
g=findall(a.view.UIFigure,'Tag','MainFittingResults');disp("COMBINED SELECTED TAB: "+string(g.SelectedTab.Title));
assert(string(g.SelectedTab.Title)=="선택 그래프 겹쳐 보기");
exportapp(a.view.UIFigure,fullfile(out,'SYNTHETIC_two_files_combined.png'));
a.view.setFilePlotMode("split");drawnow;pause(1);drawnow;
assert(string(g.SelectedTab.Title)=="선택 그래프 겹쳐 보기");exportapp(a.view.UIFigure,fullfile(out,'SYNTHETIC_two_files_split.png'));
disp('VISIBLE_MODE_CHECK_COMPLETE');
end
