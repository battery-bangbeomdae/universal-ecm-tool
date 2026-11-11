function verify_whole_file_graphs()
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
out=fullfile(root,'validation_whole_file_graphs_20261106');if ~isfolder(out),mkdir(out);end
e=string(fullfile(out,'a_EIS.csv'));h=string(fullfile(out,'b_HPPC_no_SOC.csv'));c=string(fullfile(out,'c_HPPC.csv'));
copyfile(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'),e);
T=readtable(fullfile(root,'examples','SYNTHETIC_hppc_practice.csv'),'TextType','string');
T(:,intersect({'soc_pct','temperature_C'},T.Properties.VariableNames))=[];
writetable(T,h);writetable(T,c);
o=uecm.defaults();o.Circuit="RC";o.MaxGroups=1;
raw=uecm.readInputs([e;h;c],o,"");
o.FileOptions=struct('File',c,'Type',"auto",'CurrentSign',"discharge_positive");raw.Settings=o;
model=uecm.Models.SessionModel();vm=uecm.ViewModels.MainViewModel(model);vm.acceptInput(raw);vm.diagnose();
assert(vm.Bundle.Prepared.FilePrepared{2}.Blocked);
assert(~vm.Bundle.Prepared.FilePrepared{3}.Blocked);
app=uecm.Views.MainView(vm);cleanup=onCleanup(@()delete(app));drawnow;
details=findall(groot,'Type','figure','Name','ECM · 상세 설정 및 결과');
graphs=findall(details,'Tag','FileResponse');
assert(numel(graphs)==3,'Exactly one graph per input file, not per fit.');
assert(isempty(findall(details,'Tag','ExperimentResponse')));
for file=[e;h;c]'
    ax=graphs(arrayfun(@(a)string(a.UserData.SourceFile)==file,graphs));
    assert(isscalar(ax));d=uecm.filePlotData(vm.Bundle,file);
    line=findall(ax,'Tag','FileMeasured');assert(isscalar(line));
    assert(sum(isfinite(line.YData))==d.OriginalRows);
    if d.Domain=="HPPC"
        current=findall(ax,'Tag','FileCurrent');assert(isscalar(current));
        assert(sum(isfinite(current.YData))==d.OriginalRows);
        assert(numel(ax.YAxis)==2);
        [expectedX,expectedY]=uecm.segmentPlotRows(d.Data.time,d.Data.voltage,d.Breaks);
        assert(isequaln(line.XData(:),expectedX)&&isequaln(line.YData(:),expectedY));
    end
end
mainMode=findall(app.UIFigure,'Tag','PlotDimension');assert(string(mainMode.Value)=="RMSE");
vm.SelectedFile=h;app.setPlotDimension("파일 데이터");
main=findall(app.UIFigure,'Tag','ParameterMap');
assert(isscalar(findall(main,'Tag','FileMeasured'))&&isscalar(findall(main,'Tag','FileCurrent')));
app.setOverlayFileSelection([h;c],true);
assert(isequal(app.selectedOverlayFiles(),[h;c]));
assert(isempty(app.selectedOverlayExperiments()),'Raw files must be selectable before fitting.');
a=findall(details,'Tag','OverlayHPPCResponse');
assert(numel(findall(a,'Tag','SelectedRaw'))==2);
assert(numel(findall(a,'Tag','SelectedRawCurrent'))==2);
assert(isempty(findall(a,'Tag','SelectedPrediction')));
tableUI=findall(details,'Tag','OverlayFiles');assert(size(tableUI.Data,1)==3&&tableUI.Data{2,1}&&tableUI.Data{3,1});
app.showStage("experiments");app.saveScreenshot(string(fullfile(out,'three_files_before_fitting.png')));
app.showStage("overlay");app.saveScreenshot(string(fullfile(out,'hppc_files_before_fitting.png')));
bundle=uecm.analyze(raw);vm.acceptFit(bundle);app.setFileGraphMode("파일 원본·피팅");drawnow;
assert(all(bundle.Results.source_file~=h),'Unknown-sign HPPC remains unfitted.');
assert(any(bundle.Results.source_file==c)&&any(bundle.Results.source_file==e));
assert(height(bundle.Results)==2); % Full-file graphs must not truncate to the fitted group limit.
graphs=findall(details,'Tag','FileResponse');assert(numel(graphs)==3);
for file=[e;h;c]'
    d=uecm.filePlotData(bundle,file);
    ax=graphs(arrayfun(@(a)string(a.UserData.SourceFile)==file,graphs));
    measured=findall(ax,'Tag','FileMeasured');assert(sum(isfinite(measured.YData))==d.OriginalRows);
    for index=d.FitIndices
        f=bundle.Fits{index};offset=0;
        for j=1:numel(raw.Files)
            if raw.Files(j)==file,break,end
            offset=offset+height(raw.OriginalInputs{j}.Data);
        end
        local=f.SourceRows-offset;
        assert(max(abs(d.Prediction(local)-f.Predicted))<1e-10);
    end
end
app.setOverlayFileSelection([h;c],true);
a=findall(details,'Tag','OverlayHPPCResponse');assert(numel(findall(a,'Tag','SelectedRaw'))+numel(findall(a,'Tag','SelectedMeasured'))==2);
assert(numel(findall(a,'Tag','SelectedPrediction'))==1);
assert(all(ismember(a.UserData.Files,[h;c])));
app.setOverlayFileSelection(h,false);
assert(isequal(a.UserData.Files,c));
app.setOverlayFileSelection(h,true);
app.showStage("experiments");app.saveScreenshot(string(fullfile(out,'three_files_after_fitting.png')));
% More than four files must still paginate by files, never by sweeps.
many=[e;h;c];for k=4:6
    path=string(fullfile(out,"extra_"+k+".csv"));copyfile(e,path);many(end+1)=path;
end
more=uecm.readInputs(many,o,"");vm.acceptInput(more);vm.diagnose();app.showExperimentPage(2);drawnow;
graphs=findall(details,'Tag','FileResponse');assert(numel(graphs)==2);
assert(all(ismember(string(arrayfun(@(a)a.UserData.SourceFile,graphs)),many(5:6))));
app.setOverlayFileSelection(many([1,6]),true);assert(numel(app.selectedOverlayFiles())==2);
app.setOverlaySelection([],false);assert(isempty(app.selectedOverlayFiles()));
% Reload no-SOC/unknown-sign file from a saved session and retain its raw graph.
vm.acceptInput(raw);vm.diagnose();app.setOverlayFileSelection(h,true);
app.exportTo(string(out));waitFor(@()~vm.Busy,120);assert(contains(vm.Status,"저장 완료"),vm.Status);
saved=dir(fullfile(out,'UniversalECM_*','session.mat'));[~,last]=max([saved.datenum]);folder=string(saved(last).folder);
app.setOverlaySelection([],false);app.loadSaved(fullfile(folder,'session.mat'));waitFor(@()~vm.Busy,120);
assert(isequal(app.selectedOverlayFiles(),h));
a=findall(details,'Tag','OverlayHPPCResponse');assert(isscalar(findall(a,'Tag','SelectedRaw')));
for file=["+uecm/filePlotData.m","+uecm/segmentPlotRows.m","+uecm/plotFileData.m","+uecm/plotSelectedFiles.m","+uecm/+Views/MainView.m"]
    issues=checkcode(fullfile(root,file),'-id');assert(~any(strcmp({issues.id},'PARSE')));
end
writelines("PASS: one graph per file; all raw rows shown; no-SOC/unknown-sign HPPC visible before/after fitting; current and voltage; original time preserved; models aligned to original rows; file checkbox before fitting; file pagination; raw session save/reload.",fullfile(out,'results.txt'));
disp('WHOLE_FILE_GRAPH_CHECKS_PASSED');clear cleanup;delete(vm);
end
function waitFor(predicate,seconds)
start=tic;while ~predicate(),assert(toc(start)<seconds,'UI task timeout');drawnow;pause(.1);end;drawnow;
end
