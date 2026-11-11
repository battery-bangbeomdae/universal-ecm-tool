root=string(fileparts(fileparts(mfilename('fullpath'))));addpath(root);out=fullfile(root,'output');
files=dir(fullfile(root,'tests','test*.m'));skip=["TestMergedVersions","testConverterFixes","testEISOutliers","testResearchUnits","testWorkspaceCache","testModelAccumulation","testResearchAids","testRawInput"];
R=matlab.unittest.TestResult.empty;
for item=files'
 [~,name]=fileparts(item.name);if ismember(string(name),skip),continue,end
 fprintf('MERGE_SUITE_START %s\n',name);r=runtests(fullfile(item.folder,item.name));R=[R,r]; %#ok<AGROW>
 T=table(string({R.Name})',[R.Passed]',[R.Failed]',[R.Incomplete]',[R.Duration]','VariableNames',{'Name','Passed','Failed','Incomplete','Duration'});
 writetable(T,fullfile(out,'merge_regression_tests.csv'));
 fprintf('MERGE_SUITE_DONE %s passed=%d failed=%d incomplete=%d\n',name,nnz([r.Passed]),nnz([r.Failed]),nnz([r.Incomplete]));
end
assertSuccess(R);disp('MERGE_REGRESSION_PASS');
