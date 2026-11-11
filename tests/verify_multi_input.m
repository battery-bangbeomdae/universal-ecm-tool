function verify_multi_input()
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
out=fullfile(root,'validation_multi_input_20261106');if ~isfolder(out),mkdir(out);end
a=fullfile(out,'a.csv');b=fullfile(out,'b.csv');
copyfile(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'),a);
copyfile(a,b);
o=uecm.defaults();o.Circuit="RC";
one=uecm.Models.SessionModel.loadFile(string(a),o,"");
both=uecm.Models.SessionModel.loadFile([string(a);string(b)],o,"");
assert(height(both.Data)==2*height(one.Data));
assert(numel(both.Files)==2);
fit1=uecm.analyze(one);fit2=uecm.analyze(both);
assert(~isempty(fit1.Fits));assert(numel(fit2.Fits)==2*numel(fit1.Fits));
assert(numel(unique(string(cellfun(@(f)f.SourceFile,fit2.Fits,'UniformOutput',false))))==2);
folder=uecm.exportBundle(fit2,string(out));
saved=load(fullfile(folder,'session.mat'),'bundle');
assert(numel(saved.bundle.Prepared.Input.Files)==2);
assert(isfile(fullfile(folder,'input_file_rows.csv')));
failed=false;try,uecm.readInputs([string(a);string(a)],o,"");catch ex,failed=strcmp(ex.identifier,'uecm:DuplicateFiles');end
assert(failed);
bad=fullfile(out,'different.csv');D=one.Data;D.extra_column=zeros(height(D),1);writetable(D,bad);
extra=uecm.readInputs([string(a);string(bad)],o,"");assert(height(extra.Data)==2*height(one.Data));
files={fullfile(root,'+uecm','+Views','MainView.m'),fullfile(root,'+uecm','+Models','SessionModel.m'), ...
fullfile(root,'+uecm','readInputs.m'),fullfile(root,'+uecm','analyze.m'),fullfile(root,'+uecm','exportBundle.m')};
for k=1:numel(files)
    issues=checkcode(files{k},'-id');
    assert(~any(strcmp({issues.id},'PARSE')),'MATLAB parse error');
end
model=uecm.Models.SessionModel();vm=uecm.ViewModels.MainViewModel(model);vm.acceptInput(both);app=uecm.Views.MainView(vm);drawnow;delete(app);delete(vm);
writelines("PASS: single input, batch rows, separate fitting, source paths, export/session, duplicate rejection, heterogeneous extra columns, syntax.",fullfile(out,'results.txt'));
disp('MULTI_INPUT_CHECKS_PASSED');
end
