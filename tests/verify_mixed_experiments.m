function verify_mixed_experiments()
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
out=fullfile(root,'validation_mixed_experiments_20261106');if ~isfolder(out),mkdir(out);end
e=string(fullfile(out,'eis.csv'));h=string(fullfile(out,'hppc_discharge_positive.csv'));
c=string(fullfile(out,'hppc_charge_positive.csv'));
copyfile(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'),e);
copyfile(fullfile(root,'examples','SYNTHETIC_hppc_practice.csv'),h);
T=readtable(h,'TextType','string');T.current_A=-T.current_A;writetable(T,c);
o=uecm.defaults();o.Circuit="RC";
raw=uecm.readInputs([e;h;c],o,"");
p=uecm.prepare(raw);
assert(p.Type=="mixed"&&~p.Blocked);
assert(p.FilePrepared{2}.Blocked&&p.FilePrepared{3}.Blocked);
partial=uecm.analyze(raw);
assert(~isempty(partial.Fits)&&all(partial.Results.domain=="EIS")&&partial.Status=="partial");
o.FileOptions=[struct('File',h,'Type',"auto",'CurrentSign',"discharge_positive"), ...
struct('File',c,'Type',"auto",'CurrentSign',"charge_positive")];
raw.Settings=o;p=uecm.prepare(raw);assert(~p.Blocked);
assert(all(~cellfun(@(q)q.Blocked,p.FilePrepared)));
bundle=uecm.analyze(raw);
assert(~isempty(bundle.Fits)&&any(bundle.Results.domain=="EIS")&&any(bundle.Results.domain=="HPPC"));
assert(numel(unique(bundle.Results.source_file))==3);
for k=1:3
    local=uecm.analyze(p.FilePrepared{k}.Input);
    selected=find(bundle.Results.source_file==raw.Files(k));
    assert(numel(selected)==numel(local.Fits));
    for j=1:numel(selected)
        f=bundle.Fits{selected(j)};
        assert(f.Domain==local.Fits{j}.Domain);
        assert(max(abs(f.Predicted-local.Fits{j}.Predicted))<1e-9);
        origin=raw.Data.uecm_input_file(f.SourceRows);
        assert(all(origin==raw.Files(k)));
    end
end
model=uecm.Models.SessionModel();vm=uecm.ViewModels.MainViewModel(model);
vm.acceptInput(raw);vm.acceptFit(bundle);
vm.SelectedFile=h;
[rows,~,~]=vm.chartData("soc_pct","temperature_C","R0_Ohm","모두 (점으로 비교)","모두 (주의 포함)","권장 모델","2D");
assert(~isempty(rows)&&all(rows.source_file==h));
app=uecm.Views.MainView(vm);app.setFileGraphMode("파일 원본·피팅");drawnow;
assert(numel(findall(app.UIFigure,'Tag','FileSettings'))==1);
details=findall(groot,'Type','figure','Name','ECM · 상세 설정 및 결과');
axesList=findall(details,'Tag','FileResponse');assert(numel(axesList)==3);
for j=1:numel(axesList)
    data=axesList(j).UserData;fileData=uecm.filePlotData(bundle,string(data.SourceFile));
    measured=findall(axesList(j),'Tag','FileMeasured');assert(isscalar(measured));
    assert(sum(isfinite(measured.YData))==fileData.OriginalRows);
end
app.showExperimentPage(999);drawnow;
assert(numel(findall(details,'Tag','FileResponse'))==3);
app.configureFile(h,"auto","unknown");
assert(vm.Bundle.Prepared.FilePrepared{2}.Blocked&&~vm.Bundle.Prepared.Blocked);
app.configureFile(h,"auto","discharge_positive");
vm.acceptFit(bundle);
folder=uecm.exportBundle(bundle,string(out));
saved=load(fullfile(folder,'session.mat'),'bundle');
assert(numel(unique(saved.bundle.Results.domain))==2);
assert(numel(saved.bundle.Prepared.Input.Settings.FileOptions)==2);
app.showExperimentPage(1);
app.showStage("experiments");app.saveScreenshot(string(fullfile(out,'mixed_experiments_ui.png')));
delete(app);delete(vm);
files={'+uecm/prepareBatch.m','+uecm/analyzeBatch.m','+uecm/analyze.m', ...
'+uecm/plotExperiment.m','+uecm/+Views/MainView.m','+uecm/+ViewModels/MainViewModel.m'};
for j=1:numel(files)
    issues=checkcode(fullfile(root,files{j}),'-id');
    assert(~any(strcmp({issues.id},'PARSE')));
end
writelines("PASS: mixed dispatch; independent polarity; partial processing; independent fits; provenance; file-filtered map; separate experiment axes; pagination; file-settings edits; mixed session export.",fullfile(out,'results.txt'));
disp('MIXED_EXPERIMENT_CHECKS_PASSED');
end
