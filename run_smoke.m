function R = run_smoke(tier)
%RUN_SMOKE  빠른 검수(smoke, 약 10분) 또는 전체 검수(full).
%   R = run_smoke          % smoke: 변환기·병합 지점만. 17 MB Wuppertal 원본·GUI·McMaster 비교 제외
%   R = run_smoke("full")  % 모든 tests\test*.m (20~30분 이상)
% 결과는 tests\smoke_result_<시각>.csv 로 파일마다 바로 저장되므로 중간에 멈춰도 그때까지의 결과가 남습니다.
arguments, tier (1,1) string {mustBeMember(tier,["smoke","full"])} = "smoke", end
import matlab.unittest.TestSuite
root=string(fileparts(mfilename('fullpath')));
p=string(strsplit(path,pathsep));rm=p(contains(p,"Universal_ECM_Tool"));if ~isempty(rm),rmpath(rm{:});end
addpath(root);clear functions;rehash   %#ok<CLFUNC>
old=cd(fullfile(root,"tests"));c=onCleanup(@()cd(old));
if tier=="smoke"
    files=["testConverterFixes","testRawInput","testResearchAids","testRawAxisRepairs","testCore", ...
           "testTemplateCompatibility","testCustomAxes","testConditionComparison","testUniversalInput", ...
           "TestMergedVersions","testEISOutliers","testWorkspaceCache","testModelAccumulation","testFolderImport"];   % ver.5 merge boundaries
    heavy=["testWuppertalRawOpensAndFits","testUserChoiceIsNotOverridden","testShortBlipAt1kHzDoesNotDropPulse", ...
           "testSOCAnchorAbsentIsReported","testMcMasterMatSameAsCSVAndFits","testRampedPulseAccepted", ...
           ... % team tests, 50-200 s each on 2026-11-10 smoke; unchanged by the converter merge -> full tier only
           "testActualPublishedEIS","testUnknownUnitBlocked","testMainViewMapFilterAndComparisonEntry", ...
           "testComparisonTraceAndSameSourceRows","testExportAndReloadUniqueNewFolder","testViewModelAxisQueriesDoNotChangeFit"];
else
    d=dir(fullfile(root,"tests","test*.m"));files=erase(string({d.name}),".m");heavy=strings(0,1);
end
out=fullfile(root,"tests","smoke_result_"+string(datetime('now','Format','yyyyMMdd_HHmmss'))+".csv");
R=matlab.unittest.TestResult.empty;t0=tic;
for f=files
    if ~isfile(fullfile(root,"tests",f+".m")),fprintf('  (없음) %s\n',f);continue,end
    s=TestSuite.fromFile(fullfile(root,"tests",f+".m"));
    if ~isempty(heavy),s=s(~contains(string({s.Name}),heavy));end
    t1=tic;r=run(s);R=[R,r]; %#ok<AGROW>
    fprintf('%-28s 통과 %3d  실패 %2d  미완료 %2d  (%4.0f s)\n',f,nnz([r.Passed]),nnz([r.Failed]),nnz([r.Incomplete]),toc(t1));
    T=table(string({r.Name})',[r.Passed]',[r.Failed]',[r.Incomplete]',[r.Duration]','VariableNames',{'name','passed','failed','incomplete','seconds'});
    if isfile(out),writetable(T,out,'WriteMode','append','Encoding','UTF-8');else,writetable(T,out,'Encoding','UTF-8');end
end
fprintf('\n===== %s 합계 (%.1f분): 통과 %d / 실패 %d / 미완료 %d =====\n',tier,toc(t0)/60,nnz([R.Passed]),nnz([R.Failed]),nnz([R.Incomplete]));
bad=R(~[R.Passed]);
for k=1:numel(bad)
    msg="";dr=bad(k).Details;
    if isfield(dr,'DiagnosticRecord')&&~isempty(dr.DiagnosticRecord),msg=regexprep(string(dr.DiagnosticRecord(1).Report),"\s+"," ");end
    fprintf('  ✗ %s : %s\n',bad(k).Name,extractBefore(msg+" ",min(strlength(msg)+1,220)));
end
fprintf('결과 파일: %s\n',out);
end
