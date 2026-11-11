function tests=testConsolidationOptimization
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Dir=string(tempname);mkdir(t.TestData.Dir);t.addTeardown(@()rmdir(t.TestData.Dir,'s'));
root=appRoot();o=uecm.defaults();o.Type="EIS";o.Circuit="RC";
i=uecm.readInput(fullfile(root,'examples','REAL_D010_eis_12spectra.csv'),o);
ids=unique(i.Data.spectrum_id,'stable');i.Data=i.Data(ismember(i.Data.spectrum_id,ids(1:2)),:);t.TestData.EIS=uecm.analyze(i);
o=uecm.defaults();o.Type="HPPC";o.CurrentSign="charge_positive";
i=uecm.readInput(fullfile(root,'examples','REAL_D014_hppc_one_pulse.csv'),o);t.TestData.HPPC=uecm.analyze(i);
files=strings(3,1);
for k=1:3,files(k)=fullfile(t.TestData.Dir,"actual_"+k+".csv");copyfile(fullfile(root,'examples','REAL_D014_hppc_one_pulse.csv'),files(k));end
input=uecm.readInputs(files,o,"");t.TestData.Batch=uecm.analyze(input);
end
function root=appRoot()
root=string(fileparts(fileparts(mfilename('fullpath'))));
end
function testBatchHPPCGlobalRowsLinkAllSavedFits(t)
b=t.TestData.Batch;
d=uecm.conditionComparisonData(b.Prepared);[matched,~]=uecm.comparisonFitLinks(d.Measurements,b);verifyEqual(t,nnz(matched),height(b.Results));verifyEqual(t,nnz(matched),3);
verifyGreaterThan(t,d.Measurements.onset_source_row(2),d.Measurements.onset_file_row(2));
M=table(b.Results.fit_id,[10;20;30],'VariableNames',{'fit_id','exposure_days'});b=uecm.addCustomAxis(b,M,"exposure_days","노출일","day","fit_id");
a=uecm.attachComparisonResults(d,b);verifyTrue(t,all(isfinite(a.Measurements.custom_exposure_days)));verifyTrue(t,all(~cellfun(@isempty,a.FitCandidates)));
end
function testPreparedReuseMatchesSavedParameters(t)
for domain=["EIS","HPPC"]
 old=t.TestData.(char(domain));i=old.Prepared.Input;
 b=uecm.analyze(i,@(~)[],old.Prepared);verifyEqual(t,b.Results,old.Results);
 for k=1:numel(b.Fits),verifyEqual(t,b.Fits{k}.Parameters,old.Fits{k}.Parameters);end
 changed=i;changed.Settings.Type="auto";verifyError(t,@()uecm.analyze(changed,@(~)[],old.Prepared),'uecm:PreparedInputMismatch');
end
end
function testAtomicViewModelPublicationAndSelection(t)
b=t.TestData.EIS;
m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);r=v.Revision;v.acceptInput(b.Prepared.Input);verifyEqual(t,v.Revision,r+1);verifyFalse(t,v.Updating);
r=v.Revision;s=v.SelectionRevision;v.acceptFit(b);verifyEqual(t,v.Revision,r+1);verifyEqual(t,v.SelectionRevision,s);verifyFalse(t,v.Updating);
r=v.Revision;v.selectFit(2);verifyEqual(t,v.SelectedFit,2);verifyEqual(t,v.Revision,r);verifyEqual(t,v.SelectionRevision,s+1);verifyFalse(t,v.Updating);
end
function testIntegratedFitBackgroundUsesPreparedInput(t)
b=t.TestData.EIS;
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view)); %#ok<NASGU>
a.viewModel.acceptInput(b.Prepared.Input);a.view.startAnalysis();started=tic;
while a.viewModel.Busy&&toc(started)<90,drawnow;pause(.05);end
verifyFalse(t,a.viewModel.Busy);
% Lin-KK least squares runs on a backgroundPool thread here; multithreaded BLAS may change the last bits of
% kk_max_residual (Windows MKL, 2026-11-10). Everything else must match exactly; KK residual to 1e-9 relative.
R=a.viewModel.Bundle.Results;verifyEqual(t,removevars(R,'kk_max_residual'),removevars(b.Results,'kk_max_residual'));
verifyEqual(t,R.kk_max_residual,b.Results.kk_max_residual,'RelTol',1e-9);
a.viewModel.selectFit(2);a.view.showStage("comparison");header=findall(groot,'Tag','PrimaryConditions');verifyTrue(t,contains(string(header.Text),b.Results.fit_id(2)));
end

function testSharedOutputRootAndProtection(t)
paths=uecm.workspacePaths();
% The gh/data layout exists only inside the team's shared ECM workspace. On a stand-alone copy (e.g. Desktop)
% there is no protected folder to find, but the refusal below must still hold (checked before existence).
if ~isfolder(fullfile(paths.GHRoot,'data')),log(t,1,"gh/data 없음(단독 복사본): 저장 거부 동작만 검사합니다.");end
protected=fullfile(paths.GHRoot,'data','derived');
verifyError(t,@()uecm.exportBundle(struct(),protected),'uecm:ProtectedOutput');
verifyError(t,@()uecm.exportNormalized(struct(),protected),'uecm:ProtectedOutput');
end
function testSharedComparisonJoinEquivalentToSeparateJoins(t)
b=t.TestData.HPPC;
d=uecm.conditionComparisonData(b.Prepared);
separate=uecm.attachCustomComparison(d,b);separate=uecm.attachFittedComparison(separate,b);
shared=uecm.attachComparisonResults(d,b);verifyEqual(t,shared,separate);
end
