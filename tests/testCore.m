function tests=testCore
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
t.TestData.Examples=fullfile(t.TestData.Root,'examples');
end
function testIdealEISRecovery(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);b=uecm.analyze(i);
verifyEqual(t,height(b.Results),9);verifyEqual(t,b.Results.domain,repmat("EIS",9,1));
for k=1:height(b.Results)
 r=b.Results(k,:);expectedRs=.01+.0001*(35-r.temperature_C);expectedR=.03+.0002*(80-r.soc_pct);expectedC=200+2*r.soc_pct;
 verifyEqual(t,r.Rs_Ohm,expectedRs,'RelTol',1e-3);verifyEqual(t,r.Rct_Ohm,expectedR,'RelTol',1e-3);
 verifyEqual(t,r.Cdl_F,expectedC,'RelTol',1e-3);verifyTrue(t,r.synthetic);verifyEqual(t,r.validation,"training_fit_only");
end
end
function testHPPCIndependentPulseRecovery(t)
o=uecm.defaults();o.CurrentSign="discharge_positive";
i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_hppc_practice.csv'),o);b=uecm.analyze(i);
verifyEqual(t,height(b.Results),6);
for k=1:height(b.Results)
 r=b.Results(k,:);r0=.008+.0001*(35-r.temperature_C);r1=.02+.0001*(80-r.soc_pct);tau=8+.05*(80-r.soc_pct);
 verifyEqual(t,r.R0_Ohm,r0,'RelTol',.005);verifyEqual(t,r.R1_Ohm,r1,'RelTol',.005);
 verifyEqual(t,r.tau_s,tau,'RelTol',.005);verifyEqual(t,r.C1_F,tau/r1,'RelTol',.005);
 verifyTrue(t,isnan(r.Rct_Ohm));verifyTrue(t,isnan(r.Cdl_F));verifyLessThan(t,r.rmse,1e-5);
end
end
function testMissingTimeBlocksAndResolution(t)
% This fixture is an intentionally incomplete tidy template, not an instrument raw file.
o=uecm.defaults();o.ImportMode="template";o.CurrentSign="discharge_positive";
i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_missing_time.csv'),o);b=uecm.analyze(i);
verifyEmpty(t,b.Results);verifyTrue(t,any(b.Prepared.Requests.Field=="time"));
% Provide actual original time per test, not one continuous counter across resets.
full=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_hppc_practice.csv'),o);i.Data.time_s=full.Data.time_s;i.Mapping.time="time_s";
b=uecm.analyze(i);verifyEqual(t,height(b.Results),6);verifyFalse(t,any(b.Prepared.Requests.Field=="time"));
end
function testAutoHPPCSign(t)
i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_hppc_practice.csv'));
p=uecm.prepare(i);
verifyFalse(t,p.Blocked);verifyEqual(t,p.Data.current,i.Data.current_A);
i.Data.current_A=-i.Data.current_A;
p=uecm.prepare(i);
verifyFalse(t,p.Blocked);verifyEqual(t,p.Data.current,-i.Data.current_A);
b=uecm.analyze(i);verifyEqual(t,height(b.Results),6);
i.Data.voltage_V(:)=4;
p=uecm.prepare(i);
verifyTrue(t,p.Blocked);verifyTrue(t,any(p.Requests.Field=="current_sign"));
end
function testSOCMissingDoesNotBlockPulseFit(t)
o=uecm.defaults();o.CurrentSign="discharge_positive";
i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_hppc_practice.csv'),o);i.Data.soc_pct=[];i.Mapping.soc="";
b=uecm.analyze(i);verifyEqual(t,height(b.Results),6);verifyTrue(t,all(isnan(b.Results.soc_pct)));verifyTrue(t,any(b.Prepared.Requests.Field=="soc"));
end
function testBadTimeIsNotSortedSilently(t)
o=uecm.defaults();o.CurrentSign="discharge_positive";
i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_hppc_practice.csv'),o);i.Data.time_s(3)=i.Data.time_s(2);
b=uecm.analyze(i);verifyEqual(t,height(b.Results),5);verifyTrue(t,any(contains(b.Prepared.Requests.Reason,'시간 역전')));
end
function testUnknownUnitBlocked(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);
i.Data.frequency=i.Data.frequency_hz;i.Data.frequency_hz=[];i.Mapping.frequency="frequency";b=uecm.analyze(i);
verifyEmpty(t,b.Results);verifyTrue(t,any(b.Prepared.Requests.Field=="frequency_unit"));
i.Settings.FrequencyUnit="hz";b=uecm.analyze(i);verifyEqual(t,height(b.Results),9);
end
function testDuplicateMetadataBlocks(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);
i.Metadata=table(["EIS_15_20";"EIS_15_20"],[20;50],'VariableNames',{'spectrum_id','soc_pct'});b=uecm.analyze(i);
verifyEmpty(t,b.Results);verifyTrue(t,any(b.Prepared.Requests.Field=="metadata_duplicate"));
end
function testNoRCFromDCIRSummary(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);
i.Data=table(0.02,'VariableNames',{'DCIR_Ohm'});i.Mapping=uecm.inferMapping(i.Data.Properties.VariableNames);b=uecm.analyze(i);
verifyEmpty(t,b.Results);verifyTrue(t,b.Prepared.Blocked);
end
function testActualPublishedEIS(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'REAL_D010_eis_12spectra.csv'),o);before=i.Data;
b=uecm.analyze(i);verifyEqual(t,height(b.Results),12);verifyFalse(t,any(b.Results.synthetic));verifyEqual(t,i.Data,before);
verifyTrue(t,all(isfinite(b.Results.rmse)));verifyTrue(t,all(b.Results.Rs_Ohm>0));
verifyEqual(t,numel(unique(b.Results.soc_pct)),3);verifyEqual(t,numel(unique(b.Results.temperature_C)),4);
end
function testWarburgRecoveryExcludesPositiveImaginary(t)
o=uecm.defaults();o.Circuit="RC+W";
f=logspace(4,-2,60)';w=2*pi*f;
z=.011+.024./(1+1i*w*.3)+.003*(1-1i)./sqrt(w);
z(1:3)=real(z(1:3))+1i*.01;
r=uecm.fitEIS(f,real(z),imag(z),o);
verifyEqual(t,r.ModelName,"1RC+W");
verifyEqual(t,r.SourceIndices,(4:60)');
verifyEqual(t,r.ExcludedPositiveImaginary,3);
verifyEqual(t,r.Parameters.Warburg_sigma_Ohm_s_mhalf,.003,'RelTol',1e-3);
verifyTrue(t,isnan(r.Parameters.L_H));
verifyLessThan(t,r.RMSE,1e-7);
end
function testPolarAndNegativeImaginary(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);
i.Data.magnitude_mOhm=1000*hypot(i.Data.z_real_ohm,i.Data.z_imag_ohm);i.Data.phase_deg=atan2d(i.Data.z_imag_ohm,i.Data.z_real_ohm);
i.Mapping.real="";i.Mapping.imag="";i.Mapping.magnitude="magnitude_mOhm";i.Mapping.phase="phase_deg";
p=uecm.prepare(i);verifyFalse(t,p.Blocked);verifyEqual(t,p.Data.real,i.Data.z_real_ohm,'AbsTol',1e-14);verifyEqual(t,p.Data.imag,i.Data.z_imag_ohm,'AbsTol',1e-14);
i.Mapping.magnitude="";i.Mapping.phase="";i.Mapping.real="z_real_ohm";i.Data.neg_imag_ohm=-i.Data.z_imag_ohm;i.Mapping.imag="neg_imag_ohm";
p=uecm.prepare(i);verifyEqual(t,p.Data.imag,i.Data.z_imag_ohm,'AbsTol',1e-14);
end
function testJoinedSOCAndMetadataConflict(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);
S=unique(i.Data(:,{'spectrum_id','soc_pct'}),'rows','stable');i.Metadata=S;i.Data.soc_pct=[];i.Mapping.soc="";
p=uecm.prepare(i);verifyFalse(t,p.Blocked);verifyTrue(t,all(isfinite(p.Data.soc)));
i.Data.soc_pct=ones(height(i.Data),1)*42;i.Mapping.soc="soc_pct";p=uecm.prepare(i);verifyTrue(t,p.Blocked);
end
function testSurfaceChecks(t)
T=table(repmat("same",9,1),repmat("cell",9,1),repmat("EIS",9,1),repmat("RC",9,1), ...
    repmat([20;50;80],3,1),repelem([15;25;35],3),nan(9,1),nan(9,1),(1:9)', ...
    'VariableNames',{'source_id','cell_id','domain','circuit','soc_pct','temperature_C','soh_pct','cycle_number','Rs_Ohm'});
[tri,~]=uecm.surfaceMesh(T,"soc_pct","temperature_C","Rs_Ohm");verifyNotEmpty(t,tri);
T.cell_id(1)="other";[tri,~]=uecm.surfaceMesh(T,"soc_pct","temperature_C","Rs_Ohm");verifyEmpty(t,tri);
T.cell_id(:)="unassigned";[tri,~]=uecm.surfaceMesh(T,"soc_pct","temperature_C","Rs_Ohm");verifyEmpty(t,tri);
T.cell_id(:)="cell";T.temperature_C=T.soc_pct;[tri,~]=uecm.surfaceMesh(T,"soc_pct","temperature_C","Rs_Ohm");verifyEmpty(t,tri);
end
function testExportAndReloadUniqueNewFolder(t)
o=uecm.defaults();o.MaxGroups=1;i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);b=uecm.analyze(i);
parent=string(tempname);mkdir(parent);cleanup=onCleanup(@()rmdir(parent,'s'));
f1=uecm.exportBundle(b,parent);f2=uecm.exportBundle(b,parent);verifyNotEqual(t,f1,f2);
saved=uecm.Models.SessionModel.loadFile(fullfile(f1,'session.mat'),o,"");verifyTrue(t,saved.SavedSession);verifyEqual(t,saved.Bundle.Results,b.Results);
verifyTrue(t,isfile(fullfile(f1,'settings_and_provenance.json')));clear cleanup
end
function testProtectedMeasurementFolder(t)
o=uecm.defaults();o.MaxGroups=1;i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);b=uecm.analyze(i);
paths=uecm.workspacePaths();protected=fullfile(paths.GHRoot,'data','derived');
verifyError(t,@()uecm.exportBundle(b,string(protected)),'uecm:ProtectedOutput');
end
function testActualHPPCRequestsReviewAndSOC(t)
o=uecm.defaults();o.CurrentSign="charge_positive";
i=uecm.readInput(fullfile(t.TestData.Examples,'REAL_D014_hppc_one_pulse.csv'),o);b=uecm.analyze(i);
verifyEqual(t,height(b.Results),1);verifyFalse(t,b.Results.synthetic);verifyTrue(t,isnan(b.Results.Rct_Ohm));
verifyEqual(t,b.Results.fit_status,"review");verifyTrue(t,any(b.Prepared.Requests.Field=="soc"));verifyTrue(t,any(b.Prepared.Requests.Field=="fit_1"));
end
function testViewModelAxisQueriesDoNotChangeFit(t)
o=uecm.defaults();o.MaxGroups=3;i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);b=uecm.analyze(i);
m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);clean=onCleanup(@()delete(v));v.acceptInput(i);v.acceptFit(b);before=v.Bundle.Results;
[~,~,~]=v.chartData("soc_pct","temperature_C","Rs_Ohm","모두 (점으로 비교)","모두 (주의 포함)");
[~,~,~]=v.chartData("soc_pct","temperature_C","Rct_Ohm","모두 (점으로 비교)","후보만");verifyEqual(t,v.Bundle.Results,before);clear clean
end
function testEmptyDataRequestsActualRows(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);i.Data=i.Data([],:);
p=uecm.prepare(i);verifyTrue(t,p.Blocked);verifyTrue(t,any(p.Requests.Field=="data"));
end
function testAmbiguousTypeRequiresSelection(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);
i.Data.time_s=(1:height(i.Data))';i.Data.current_A=zeros(height(i.Data),1);i.Data.voltage_V=ones(height(i.Data),1)*4;
i.Mapping.time="time_s";i.Mapping.current="current_A";i.Mapping.voltage="voltage_V";
p=uecm.prepare(i);verifyTrue(t,p.Blocked);verifyTrue(t,any(p.Requests.Field=="type"));
i.Settings.Type="EIS";p=uecm.prepare(i);verifyFalse(t,p.Blocked);
end
function testKnownTwoRCEISRecoveredAndCompared(t)
o=uecm.defaults();i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_2RC_eis_practice.csv'),o);b=uecm.analyze(i);r=b.Results(1,:);f=b.Fits{1};
verifyEqual(t,r.model,"2RC");verifyEqual(t,r.R1_Ohm,.02,'RelTol',.01);verifyEqual(t,r.C1_F,5,'RelTol',.01);
verifyEqual(t,r.R2_Ohm,.035,'RelTol',.01);verifyEqual(t,r.tau2_s,20,'RelTol',.01);
S=f.CandidateScores;verifyEqual(t,height(S),4);verifyLessThan(t,S.RMSE(S.Model=="2RC"),S.RMSE(S.Model=="1RC")/100);
verifyTrue(t,all(isnan(S.ValidationRMSE)));verifyTrue(t,all(S.NPoints==110));
end
function testKnownTwoRCHPPCRecovered(t)
o=uecm.defaults();o.CurrentSign="discharge_positive";o.MaxGroups=1;
i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_2RC_hppc_practice.csv'),o);b=uecm.analyze(i);r=b.Results(1,:);
verifyEqual(t,r.model,"2RC");verifyEqual(t,r.R0_Ohm,.009,'RelTol',.01);verifyEqual(t,r.R1_Ohm,.014,'RelTol',.01);
verifyEqual(t,r.R2_Ohm,.022,'RelTol',.01);verifyEqual(t,r.tau1_s,3,'RelTol',.01);verifyEqual(t,r.tau2_s,35,'RelTol',.01);
S=b.Fits{1}.CandidateScores;verifyLessThan(t,S.RMSE(S.Model=="2RC"),S.RMSE(S.Model=="1RC")/100);
end
function testOneRCDoesNotAutomaticallyBecomeTwoRC(t)
o=uecm.defaults();o.CurrentSign="discharge_positive";o.MaxGroups=1;
i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_hppc_practice.csv'),o);b=uecm.analyze(i);f=b.Fits{1};
verifyEqual(t,f.ModelName,"1RC");verifyTrue(t,any(f.CandidateScores.Model=="2RC"));
verifyEqual(t,f.CandidateScores.Status(f.CandidateScores.Model=="2RC"),"review");
end
function testComparisonTraceAndSameSourceRows(t)
o=uecm.defaults();o.MaxGroups=1;i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_eis_practice.csv'),o);b=uecm.analyze(i);f=b.Fits{1};
for c=f.Alternatives'
 a=c{1};verifyEqual(t,a.SourceRows,f.SourceRows);verifyEqual(t,a.Measured,f.Measured);verifyNotEmpty(t,a.History);verifyNotEmpty(t,a.StartSummary);
 verifyTrue(t,all(isfinite(a.History.ScaledSSE)));verifyTrue(t,all(a.History.ScaledSSE>=0));
end
end
function testMapModelSelectsActualTwoRCWithoutRecalculation(t)
o=uecm.defaults();o.CurrentSign="discharge_positive";o.MaxGroups=1;i=uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_2RC_hppc_practice.csv'),o);b=uecm.analyze(i);
m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);clean=onCleanup(@()delete(v));v.acceptInput(i);v.acceptFit(b);before=v.Bundle;
[T,idx,~]=v.chartData("soc_pct","temperature_C","R1_Ohm","모두 (점으로 비교)","모두 (주의 포함)","1RC");verifyEqual(t,height(T),height(b.Results));verifyEqual(t,idx,(1:height(b.Results))');verifyEqual(t,T.model,repmat("1RC",height(T),1));
[T,~,~]=v.chartData("soc_pct","temperature_C","R2_Ohm","모두 (점으로 비교)","모두 (주의 포함)","2RC");verifyEqual(t,T.model,repmat("2RC",height(T),1));verifyTrue(t,all(isfinite(T.R2_Ohm)));verifyEqual(t,v.Bundle,before);clear clean
end
