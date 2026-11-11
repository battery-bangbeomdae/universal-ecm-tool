function tests=testResearchAids
%TESTRESEARCHAIDS Lin-KK validity check, next-measurement suggestion, methods record (added 2026-11-09).
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
t.TestData.Examples=fullfile(t.TestData.Root,'examples');
end
% ------------------------------------------------------------------ Lin-KK
function testKKPassesForCausalCircuit(t)
f=logspace(4,-2,61)';w=2*pi*f;z=0.02+0.03./(1+1i*w*0.06)+0.01./(1+1i*w*5)+1i*w*1e-7;   % R0 + 2 RC + L
kk=uecm.linKK(f,real(z),imag(z));
verifyEqual(t,kk.Status,"pass");verifyLessThan(t,kk.MaxResidual,1e-3);
end
function testKKFlagsDriftingSpectrum(t)
% SOC drift during a slow low-frequency sweep: real part grows 8 % below 1 Hz while the imaginary part does not
f=logspace(4,-2,61)';w=2*pi*f;z=0.02+0.03./(1+1i*w*0.06);re=real(z);im=imag(z);
low=f<1;re(low)=re(low).*(1+0.08*(log10(1)-log10(f(low)))/2);
kk=uecm.linKK(f,re,im);
verifyEqual(t,kk.Status,"review");verifyGreaterThan(t,kk.MaxResidual,0.01);verifyNotEmpty(t,kk.BadFrequencies);
verifyLessThan(t,max(kk.BadFrequencies),10);                               % flagged where the drift is
end
function testKKTooFewPointsNotRun(t)
kk=uecm.linKK([1;10;100],[1;1;1],[-1;-1;-1]);verifyEqual(t,kk.Status,"not_run");
end
function testKKColumnsInEISResults(t)
b=uecm.analyze(uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_2RC_eis_practice.csv'),uecm.defaults()));
verifyTrue(t,all(ismember(["kk_status","kk_max_residual"],string(b.Results.Properties.VariableNames))));
verifyTrue(t,all(b.Results.kk_status=="pass"));                            % synthetic 2RC is KK-consistent
end
% ------------------------------------------------------------------ next measurement suggestion
function testSuggestsGapWhereParameterChangesMost(t)
soc=[10;30;50;70;90];R0=[0.040;0.022;0.020;0.0195;0.019];                 % steep at low SOC
R=table(repmat("cellA",5,1),repmat(25,5,1),repmat("HPPC",5,1),soc,R0,R0*1.5,repmat("candidate",5,1), ...
    'VariableNames',{'cell_id','temperature_C','domain','soc_pct','R0_Ohm','R1_Ohm','fit_status'});
[N,S]=uecm.suggestNextMeasurements(R);
verifyEqual(t,N.suggest_soc_pct(1),20);verifyEqual(t,N.between_low_pct(1),10);verifyEqual(t,N.between_high_pct(1),30);
verifyTrue(t,ismember(70,S.soc_pct));                                       % 70 % is predicted by 50/90 within 2 %
verifyFalse(t,ismember(30,S.soc_pct));                                      % 30 % is not
end
function testSuggestionNeedsSOC(t)
R=table("c",25,"HPPC",0.02,'VariableNames',{'cell_id','temperature_C','domain','R0_Ohm'});
[N,S,info]=uecm.suggestNextMeasurements(R);verifyEmpty(t,N);verifyEmpty(t,S);verifyNotEmpty(t,info.Notes);
end
function testSuggestionsSeparateTemperatures(t)
soc=[20;50;80];R=table(repmat("c",6,1),[25;25;25;0;0;0],repmat("HPPC",6,1),[soc;soc],[0.02;0.02;0.02;0.06;0.03;0.03], ...
    'VariableNames',{'cell_id','temperature_C','domain','soc_pct','R0_Ohm'});
N=uecm.suggestNextMeasurements(R);
verifyEqual(t,N.temperature_C(1),0);verifyEqual(t,N.suggest_soc_pct(1),35);
end
% ------------------------------------------------------------------ methods record
function testMethodsSummaryListsFactsAndFingerprint(t)
b=uecm.analyze(uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_2RC_eis_practice.csv'),uecm.defaults()));
f=fullfile(tempdir,"uecm_methods_test.md");if isfile(f),delete(f);end
txt=uecm.methodsSummary(b,f);
verifyTrue(t,isfile(f));verifyTrue(t,contains(txt,"SYNTHETIC_2RC_eis_practice.csv"));
verifyTrue(t,contains(txt,uecm.codeFingerprint()));verifyTrue(t,contains(txt,"Kramers"));
verifyTrue(t,contains(txt,"2RC"));
end
function testExportWritesAids(t)
b=uecm.analyze(uecm.readInput(fullfile(t.TestData.Examples,'SYNTHETIC_2RC_eis_practice.csv'),uecm.defaults()));
out=fullfile(tempdir,"uecm_aid_export");if ~isfolder(out),mkdir(out);end
folder=uecm.exportBundle(b,string(out));c=onCleanup(@()rmdir(folder,'s'));
verifyTrue(t,isfile(fullfile(folder,'methods_summary_ko.md')));
end
function testFingerprintChangesWithCode(t)
d=fullfile(tempdir,"uecm_fp");if isfolder(d),rmdir(d,'s');end;mkdir(d);c=onCleanup(@()rmdir(d,'s'));
writelines("function a=x(),a=1;end",fullfile(d,"x.m"));h1=uecm.codeFingerprint(d);
writelines("function a=x(),a=2;end",fullfile(d,"x.m"));h2=uecm.codeFingerprint(d);
verifyNotEqual(t,h1,h2);verifyTrue(t,endsWith(h1,"-1files"));
end
