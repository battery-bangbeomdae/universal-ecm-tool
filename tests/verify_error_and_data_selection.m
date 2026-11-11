function verify_error_and_data_selection()
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
out=fullfile(root,'validation_error_selection_20261106');if ~isfolder(out),mkdir(out);end
previous=dir(fullfile(root,'validation_mixed_experiments_20261106','UniversalECM_*','session.mat'));
assert(~isempty(previous));[~,last]=max([previous.datenum]);
saved=load(fullfile(previous(last).folder,'session.mat'),'bundle');b=saved.bundle;
% Controlled constant residuals verify the RMSE numbers independently.
for k=1:numel(b.Fits)
    f=b.Fits{k};cc=uecm.candidatesOf(f);
    for j=1:numel(cc)
        cc{j}.Predicted=cc{j}.Measured+.001*j;
        cc{j}.RMSE=.001*j;
    end
    f.Alternatives=cc;pick=find(cellfun(@(c)c.ModelName==f.ModelName,cc),1);
    f.Predicted=cc{pick}.Predicted;f.RMSE=.001*pick;b.Fits{k}=f;b.Results.rmse(k)=f.RMSE;
end
paths=b.Prepared.Input.Files;
for file=paths'
    [S,total]=uecm.fileErrorSummary(b,file);assert(~isempty(S));
    fitIndices=find(b.Results.source_file==file);sumSq=0;n=0;
    for k=fitIndices'
        f=b.Fits{k};sumSq=sumSq+sum(abs(f.Measured-f.Predicted).^2);n=n+numel(f.Measured);
        cc=uecm.candidatesOf(f);
        for j=1:numel(cc)
            row=S(S.fit_index==k&S.model==cc{j}.ModelName,:);
            assert(abs(row.rmse-.001*j)<1e-12);
        end
    end
    assert(abs(total.RMSE-sqrt(sumSq/n))<1e-12&&total.NPoints==n);
end
model=uecm.Models.SessionModel();vm=uecm.ViewModels.MainViewModel(model);vm.acceptInput(b.Prepared.Input);vm.acceptFit(b);
app=uecm.Views.MainView(vm);cleanup=onCleanup(@()delete(app));drawnow;
details=findall(groot,'Type','figure','Name','ECM · 상세 설정 및 결과');
mode=findall(details,'Tag','FileErrorMode');assert(string(mode.Value)=="RMSE");
graphs=findall(details,'Tag','FileResponse');assert(numel(graphs)==numel(paths));
for ax=graphs'
    assert(~isempty(findall(ax,'Tag','FileRMSE')));
    assert(isfield(ax.UserData,'OverallRMSE')&&isfinite(ax.UserData.OverallRMSE));
end
app.showStage("experiments");app.saveScreenshot(string(fullfile(out,'file_rmse.png')));
app.setFileGraphMode("잔차");drawnow;
graphs=findall(details,'Tag','FileResponse');
for ax=graphs',assert(~isempty(findall(ax,'Tag','FileResidual')));end
app.saveScreenshot(string(fullfile(out,'file_residual.png')));
h=find(b.Results.domain=="HPPC",1);e=find(b.Results.domain=="EIS",1);file=b.Results.source_file(h);
app.setOverlayFileSelection(paths,true);
app.selectFileDatasets(file,false);app.setDatasetOption(h,"enabled",true);
app.selectOverlayScope(file);drawnow;
tableUI=findall(details,'Tag','OverlayDatasets');rows=tableUI.UserData;
assert(numel(rows)==sum(b.Results.source_file==file));
r=find(rows==h);assert(tableUI.Data{r,1});
others=find(b.Results.source_file==file);others(others==h)=[];
assert(~any(ismember(app.selectedOverlayExperiments(),others)));
% Keep exactly one EIS and one HPPC dataset across checked files.
for p=paths',app.selectFileDatasets(p,false);end
app.setDatasetOption(e,"enabled",true);app.setDatasetOption(h,"enabled",true);
app.setDatasetOption(h,"1RC",true);app.setDatasetOption(h,"2RC",false);
app.setDatasetOption(h,"measured",false);app.selectOverlayScope(file);
a=findall(details,'Tag','OverlayHPPCResponse');rx=findall(details,'Tag','OverlayHPPCResidual');
assert(isequal(a.UserData.FitIndices,h));assert(numel(a.YAxis)==1);
assert(isempty(findall(a,'Tag','SelectedMeasured')));
pred=findall(a,'Tag','SelectedPrediction');assert(isscalar(pred)&&pred.UserData.Model=="1RC");
assert(isscalar(findall(rx,'Tag','SelectedResidual')));
assert(max(abs(ylim(rx)))<.01,'Millivolt residual must be readable, not hidden on a +/-1 V scale.');
% Drive the actual table checkbox callbacks for measured/2RC.
callback=tableUI.CellEditCallback;row=find(tableUI.UserData==h);
callback(tableUI,struct('Indices',[row,3],'NewData',true));
callback(tableUI,struct('Indices',[row,5],'NewData',true));
assert(isscalar(findall(a,'Tag','SelectedMeasured')));
assert(numel(findall(a,'Tag','SelectedPrediction'))==2);
callback(tableUI,struct('Indices',[row,4],'NewData',false));
pred=findall(a,'Tag','SelectedPrediction');assert(isscalar(pred)&&pred.UserData.Model=="2RC");
app.setOverlayModels(false);assert(isempty(findall(a,'Tag','SelectedPrediction')));
app.setOverlayModels(true);
app.setOverlayFileSelection(file,false);assert(isempty(a.UserData.FitIndices));
app.setOverlayFileSelection(file,true);app.selectFileDatasets(file,false);app.setDatasetOption(h,"enabled",true);
assert(isequal(sort(app.selectedOverlayExperiments()),sort([e;h])));
app.showStage("overlay");app.saveScreenshot(string(fullfile(out,'checked_data_and_models.png')));
app.setFileGraphMode("RMSE");app.exportTo(string(out));waitFor(@()~vm.Busy,120);
assert(contains(vm.Status,"저장 완료"),vm.Status);
created=dir(fullfile(out,'UniversalECM_*','session.mat'));[~,last]=max([created.datenum]);folder=string(created(last).folder);
for name=["file_error_summary.csv","model_error_by_dataset.csv","plot_selection.csv"]
    assert(isfile(fullfile(folder,name)));
end
stored=load(fullfile(folder,'session.mat'),'viewSettings');
before=stored.viewSettings;
app.setOverlaySelection([],false);app.loadSaved(fullfile(folder,'session.mat'));waitFor(@()~vm.Busy,120);
assert(isequal(sort(app.selectedOverlayExperiments()),sort([e;h])));
app.selectOverlayScope(file);tableUI=findall(details,'Tag','OverlayDatasets');row=find(tableUI.UserData==h);
assert(tableUI.Data{row,3}&&~tableUI.Data{row,4}&&tableUI.Data{row,5});
mode=findall(details,'Tag','FileErrorMode');assert(string(mode.Value)=="RMSE");
assert(isequal(before.OverlayDataEnabled,stored.viewSettings.OverlayDataEnabled));
for name=["+uecm/fileErrorSummary.m","+uecm/plotFileErrors.m","+uecm/plotSelectedFitData.m","+uecm/+Views/MainView.m","+uecm/exportBundle.m"]
    issues=checkcode(fullfile(root,name),'-id');assert(~any(strcmp({issues.id},'PARSE')));
end
writelines("PASS: known 1mV/2mV RMSE; point-weighted file RMSE; per-file RMSE and residual graphs; file parent selection; per-dataset checkbox; measured/1RC/2RC toggles; EIS/HPPC separation; exact trace exclusion; saved checkbox restoration; error CSV export.",fullfile(out,'results.txt'));
disp('ERROR_DATA_SELECTION_CHECKS_PASSED');clear cleanup;delete(vm);
end
function waitFor(predicate,seconds)
start=tic;while ~predicate(),assert(toc(start)<seconds,'UI task timeout');drawnow;pause(.1);end;drawnow;
end
