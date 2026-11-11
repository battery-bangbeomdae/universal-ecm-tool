root=fileparts(fileparts(mfilename('fullpath')));addpath(root);a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));
main=findall(a.view.UIFigure,'Tag','MainFittingResults');assert(numel(main)==1);assert(isempty(findall(a.view.UIFigure,'Tag','InputPreview')));info=findall(groot,'Tag','InputInformationWindow');assert(numel(findall(info,'Tag','InputPreview'))==1);ax=findall(a.view.UIFigure,'Tag','ParameterMap');x=findall(a.view.UIFigure,'Tag','XAxisChoice');assert(x.Parent.Layout.Row>ax.Layout.Row);
d=string(tempname);mkdir(d);T=readtable(fullfile(root,'examples','REAL_D010_eis_12spectra.csv'),'TextType','string');T=T(T.spectrum_id==T.spectrum_id(1),:);file=fullfile(d,'eis.csv');writetable(T,file);o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;input=uecm.workspaceLoad(file,o,"",struct(),struct());a.viewModel.acceptWorkspace(input.Input,input.Bundle);
for family=["RC","2RC","CPE","2CPE"],box=findall(a.view.UIFigure,'Tag',"EISModel_"+family);box.Value=true;feval(box.ValueChangedFcn,box,[]);end
box=findall(a.view.UIFigure,'Tag','EISAutoWarburg');box.Value=true;feval(box.ValueChangedFcn,box,[]);
a.view.startAnalysis();wait(a);assert(~isempty(a.viewModel.Bundle.Results),a.viewModel.Status);assert(isempty(a.viewModel.Bundle.CacheWarnings),join(a.viewModel.Bundle.CacheWarnings,newline));
a.view.showStage("comparison");drawnow;
ax=findall(a.view.UIFigure,'Tag','PrimaryResponse');assert(a.viewModel.Bundle.Fits{1}.ExcludedOutlierCount==2);
assert(numel(findall(ax,'Tag','EISExcluded_statistical_outlier'))==1);assert(ax.XLim(1)>-.01&&ax.XLim(2)<.012);
a.view.saveScreenshot(fullfile(root,'output','eis_outliers_20261110','nyquist_recommended_focused.png'));
box=findall(a.view.UIFigure,'Tag','EISFullRange');box.Value=true;feval(box.ValueChangedFcn,box,[]);drawnow;assert(ax.XLim(1)<-.02);
a.view.saveScreenshot(fullfile(root,'output','eis_outliers_20261110','nyquist_recommended_all_points.png'));
box.Value=false;feval(box.ValueChangedFcn,box,[]);box=findall(a.view.UIFigure,'Tag','EISShowExcluded');box.Value=false;feval(box.ValueChangedFcn,box,[]);assert(isempty(findall(ax,'Tag','EISExcluded_statistical_outlier')));box.Value=true;feval(box.ValueChangedFcn,box,[]);
folder=uecm.exportBundle(a.viewModel.Bundle,d,struct());report=readtable(fullfile(folder,'fit_0001_eis_preprocessing.csv'));assert(nnz(report.StatisticalOutlier)==2);assert(nnz(report.PositiveImaginary)==18);assert(nnz(report.UnstableRepeat)==10);disp('OUTLIER_ALL_MODELS_UI_PASS');disp(a.viewModel.Bundle.Fits{1}.CandidateScores);clear cleanup;rmdir(d,'s');
r=runtests(fullfile(root,'tests','testEISOutliers.m'));assertSuccess(r);
function wait(a)
t=tic;while a.viewModel.Busy&&toc(t)<120,drawnow;pause(.1);end;assert(~a.viewModel.Busy,a.viewModel.Status);drawnow;
end
