function tests=testConditionCoverage
tests=functiontests(localfunctions);
end
function setup(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
t.TestData.Output=string(tempname);mkdir(t.TestData.Output);t.addTeardown(@()rmdir(t.TestData.Output,'s'));
end
function testMissingPartialAndSuspectedColumns(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
i.Data.soc_pct(1)=NaN;i.Data.soh_pct(:)=NaN;i.Data.unparsed_calendar_label=repmat("see README",height(i.Data),1);
p=uecm.prepare(i);C=p.AxisCoverage;
verifyFalse(t,p.Blocked);s=C(C.field=="soc_pct",:);verifyEqual(t,s.partial_groups,1);
s=C(C.field=="soh_pct",:);verifyEqual(t,s.missing_groups,s.measurement_groups);
s=C(C.field=="calendar_days",:);verifyTrue(t,contains(s.possible_source_columns,"unparsed_calendar_label"));
[message,missing]=uecm.coverageMessage(C);verifyTrue(t,missing);verifyTrue(t,contains(message,"원본에 없다는 뜻은 아닙니다"));
end
function testReportWorksWhenSignalsAreBlocked(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'));i.Mapping.frequency="";
p=uecm.prepare(i);verifyTrue(t,p.Blocked);dest=uecm.exportConditionReport(p,t.TestData.Output);
verifyTrue(t,isfile(fullfile(dest,'axis_condition_coverage.csv')));verifyTrue(t,isfile(fullfile(dest,'LLM_condition_review_ko.md')));
end
function testUIAndNormalizedCSVReport(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_eis_practice.csv'));
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));a.viewModel.acceptInput(i);a.viewModel.diagnose();
grid=findall(findall(groot,'Tag','InputInformationWindow'),'Tag','AxisConditionCoverage');verifyEqual(t,height(grid.Data),7);
notice=findall(findall(groot,'Tag','InputInformationWindow'),'Tag','AxisCoverageNotice');verifyTrue(t,contains(string(notice.Text),"미연결"));
dest=uecm.exportNormalized(i,t.TestData.Output);verifyTrue(t,isfile(fullfile(dest,'axis_condition_coverage.csv')));
end

function testEmptySignalCannotClaimAllConditionsConnected(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','REAL_D010_eis_12spectra.csv'));i.Data=i.Data([],:);
p=uecm.prepare(i);[~,missing]=uecm.coverageMessage(p.AxisCoverage);verifyTrue(t,missing);verifyTrue(t,p.Blocked);
end
