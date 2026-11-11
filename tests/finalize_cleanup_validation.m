function finalize_cleanup_validation()
root=fileparts(fileparts(mfilename('fullpath')));out=fullfile(root,'merge_provenance','v8_1_ui_cleanup');
s=load(fullfile(out,'test_results.mat'),'r');r=s.r;
a=load(fullfile(out,'corrected_cleanup_tests.mat'),'r');[found,pos]=ismember(string({a.r.Name}),string({r.Name}));assert(all(found));r(pos)=a.r;
a=load(fullfile(out,'metadata_final_test.mat'),'r');[found,pos]=ismember(string({a.r.Name}),string({r.Name}));assert(all(found));r(pos)=a.r;
assert(all([r.Passed]));save(fullfile(out,'final_test_results.mat'),'r');
writelines("Passed "+sum([r.Passed])+" / "+numel(r)+"; Failed "+sum([r.Failed])+"; Incomplete "+sum([r.Incomplete]),fullfile(out,'test_summary.txt'));
for f=["+uecm/+Views/MainView.m","+uecm/+ViewModels/MainViewModel.m","+uecm/plotParameterFiles.m","+uecm/measurementBrief.m"]
 issues=checkcode(fullfile(root,f),'-id');assert(~any(strcmp({issues.id},'PARSE')));
end
disp('CLEANUP_FINAL_VALIDATED');
end
