function tests=testRawInput
%TESTRAWINPUT Raw instrument files -> MATLAB conversion -> fit-ready input (added 2026-11-06 on top of v2).
% Expected fit numbers come from an independent Python port of fitHPPC run on the same fixture files.
% REAL fixtures: Samsung 30T (McMaster, CC BY 4.0), Warwick LG M50 EIS (CC BY 4.0),
% Wuppertal Samsung 50E MCU1 Batch1 excerpt (Zenodo 10891871, CC BY-NC 4.0). *_SYNTHETIC_* = layout checks only.
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
t.TestData.Fx=fullfile(t.TestData.Root,'tests','fixtures_raw');
end
% ------------------------------------------------------------------ REAL: Wuppertal cell tester (the target case)
function testWuppertalRawOpensAndFits(t)
f=fullfile(t.TestData.Fx,'wuppertal_50E_MCU1_REAL_excerpt_HPPC1.csv');
i=uecm.readInput(f,uecm.defaults());r=i.RawReport;
verifyEqual(t,r.Profile,"wuppertal_celltester");verifyEqual(t,r.Kind,"HPPC");
m=r.Mapping;
verifyEqual(t,m.source_column(m.role=="current_A"),"I [A]");          % not Itarget / I_soll
verifyEqual(t,m.source_column(m.role=="voltage_V"),"U [V]");
verifyEqual(t,m.source_column(m.role=="temperature_C"),"Temp[1] [°C]"); % cell, not ClimaTemp
verifyEqual(t,r.DroppedRows,5);                                        % event rows without I/U
verifyEqual(t,i.Settings.CurrentSign,"charge_positive");               % from data: V rises with +I
verifyEqual(t,i.Settings.DuplicateTimePolicy,"keep_last");
verifyEqual(t,i.Settings.MaxPulseDuration_s,60);
b=uecm.analyze(i);
verifyEqual(t,height(b.Results),2);                                    % discharge + charge pulse
R0=zeros(1,2);
for k=1:2
    S=b.Fits{k}.Alternatives;names=cellfun(@(c)string(c.ModelName),S);
    R0(k)=S{names=="2RC"}.Parameters.R0_Ohm;
end
verifyEqual(t,R0,[0.017942 0.018031],'RelTol',0.03);
% ver_3: time screening runs at import (cleanImportedTimeSeries) and is reported in RawReport.Hints, not b.Screening
verifyTrue(t,any(contains(i.RawReport.Hints,"keep_last")));
verifyClass(t,b.Results.source_id,'string');verifyEqual(t,numel(unique(b.Prepared.Data.source)),1);
end
function testUserChoiceIsNotOverridden(t)
o=uecm.defaults();o.CurrentSign="discharge_positive";o.MaxPulseDuration_s=30;
i=uecm.readInput(fullfile(t.TestData.Fx,'wuppertal_50E_MCU1_REAL_excerpt_HPPC1.csv'),o);
verifyEqual(t,i.Settings.CurrentSign,"discharge_positive");verifyEqual(t,i.Settings.MaxPulseDuration_s,30);
verifyFalse(t,any(contains(i.RawReport.Applied,"CurrentSign")));
end
% ------------------------------------------------------------------ REAL: Digatron CSV / McMaster MAT (Samsung 30T)
function testDigatronRawCSV(t)
[T,r]=uecm.readRaw(fullfile(t.TestData.Fx,'digatron_30T_25C_HPPC_first1100s.csv'));
verifyEqual(t,r.Profile,"digatron_csv");verifyEqual(t,r.Kind,"HPPC");
verifyEqual(t,height(T),1736);verifyEqual(t,T.voltage_V(1),4.18647,'AbsTol',1e-12);
verifyEqual(t,T.time_s(1),2*3600+36*60+33.862,'AbsTol',1e-9);       % Prog Time 02:36:33.862
end
function testMcMasterMatSameAsCSVAndFits(t)
[M,r]=uecm.readRaw(fullfile(t.TestData.Fx,'mcmaster_30T_25C_HPPC_first1100s.mat'));
[C,~]=uecm.readRaw(fullfile(t.TestData.Fx,'digatron_30T_25C_HPPC_first1100s.csv'));
verifyTrue(t,startsWith(r.Profile,"mat_struct"));verifyEqual(t,M.voltage_V,C.voltage_V,'AbsTol',1e-12);
i=uecm.readInput(fullfile(t.TestData.Fx,'digatron_30T_25C_HPPC_first1100s.csv'),uecm.defaults());
verifyEqual(t,i.Settings.CurrentSign,"charge_positive");b=uecm.analyze(i);verifyEqual(t,height(b.Results),2);
S=b.Fits{2}.Alternatives;names=cellfun(@(c)string(c.ModelName),S);
verifyEqual(t,S{names=="2RC"}.Parameters.R0_Ohm,0.009513,'RelTol',0.02);
verifyEqual(t,S{names=="1RC"}.Parameters.R0_Ohm,0.012207,'RelTol',0.02);
end
% ------------------------------------------------------------------ REAL: Warwick LG M50 EIS (headerless MAT/XLS)
function testWarwickRawMatXlsEqualTemplate(t)
fx=t.TestData.Fx;
[M,r]=uecm.readRaw(fullfile(fx,'Cell28_100SOH_25degC_50SOC_10000.mat'));
[X,~]=uecm.readRaw(fullfile(fx,'Cell28_100SOH_25degC_50SOC_10000.xls'));
R=readtable(fullfile(fx,'REAL_LGM50_Cell28_SOC50_25C_EIS.csv'));R=sortrows(R,'frequency_hz','descend');
verifyEqual(t,r.Kind,"EIS");verifyTrue(t,contains(r.Profile,"warwick_lgm50_eis"));
verifyEqual(t,M.z_real_ohm,R.z_real_ohm,'AbsTol',1e-12);verifyEqual(t,X.z_imag_ohm,M.z_imag_ohm,'AbsTol',1e-12);
verifyEqual(t,M.temperature_C(1),25);verifyEqual(t,M.soc_pct(1),50);verifyEqual(t,M.cell_id(1),"Cell28");
end
function testWarwickNominalLabelKeptSeparate(t)
[M,r]=uecm.readRaw(fullfile(t.TestData.Fx,'Cell24_90SOH_25degC_50SOC_8104.mat'));
verifyEqual(t,M.soh_label_pct(1),90);verifyEqual(t,M.soh_tag_raw(1),8104);
verifyFalse(t,ismember("soh_pct",string(M.Properties.VariableNames)));verifyTrue(t,any(contains(r.Hints,"측정 SOH")));
end
function testWarwickOpensInAppPathAndFits(t)
i=uecm.readInput(fullfile(t.TestData.Fx,'Cell28_100SOH_25degC_50SOC_10000.mat'),uecm.defaults());
b=uecm.analyze(i);verifyEqual(t,b.Prepared.Type,"EIS");verifyEqual(t,height(b.Results),1);
end
function testConvertRawFolder(t)
tmp=string(tempname);mkdir(tmp);cleanup=onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
out=fullfile(tmp,'uecm_warwick_test.csv');
[T,log]=uecm.convertRawFolder(t.TestData.Fx,out,"Cell*.mat");
verifyEqual(t,height(log),3);verifyEqual(t,numel(unique(T.spectrum_id)),3);
b=uecm.analyze(uecm.readInput(out,uecm.defaults()));verifyEqual(t,height(b.Results),3);
end
% ------------------------------------------------------------------ layout rules (SYNTHETIC values)
function testECLabDecimalCommaNegativeImag(t)
[T,r]=uecm.readRaw(fullfile(t.TestData.Fx,'eclab_EIS_SYNTHETIC_decimalcomma.mpt'));
verifyEqual(t,r.Kind,"EIS");f=logspace(5,-1,61)';z=1i*2*pi*f*1e-7+.02+.03./(1+1i*2*pi*f*.01);
verifyEqual(t,T.z_real_ohm,real(z),'RelTol',1e-8);verifyEqual(t,T.neg_im_z_ohm,-imag(z),'RelTol',1e-8);
end
function testSignedRXColumnsWithImpedanceUnits(t)
folder=string(tempname);mkdir(folder);
cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
file=fullfile(folder,'rx_eis.csv');
writelines(["Frequency [Hz],R [mOhm],X [mOhm]";"1000,12,1";"100,13,-2";"10,14,-3"],file);
input=uecm.readInput(file,uecm.defaults());
verifyEqual(t,input.RawReport.Kind,"EIS");
prepared=uecm.prepare(input);
verifyEqual(t,prepared.Data.real,[.012;.013;.014],'AbsTol',1e-12);
verifyEqual(t,prepared.Data.imag,[.001;-.002;-.003],'AbsTol',1e-12);
end
function testGamryUnitsRow(t)
[T,r]=uecm.readRaw(fullfile(t.TestData.Fx,'gamry_EIS_SYNTHETIC.dta'));
verifyEqual(t,r.Kind,"EIS");verifyEqual(t,height(T),61);verifyTrue(t,ismember("z_imag_ohm",string(T.Properties.VariableNames)));
end
function testWhitespaceIndexColumnPolar(t)
[T,~]=uecm.readRaw(fullfile(t.TestData.Fx,'whitespace_index_EIS_SYNTHETIC.txt'));
verifyTrue(t,all(ismember(["magnitude_ohm","phase_deg"],string(T.Properties.VariableNames))));verifyEqual(t,height(T),61);
end
function testArbinIdsAndUnknownUnitsRequested(t)
[T,r]=uecm.readRaw(fullfile(t.TestData.Fx,'arbin_like_EIS_SYNTHETIC_2spectra.csv'));
verifyEqual(t,numel(unique(T.spectrum_id)),2);verifyTrue(t,any(contains(r.Requests,"단위를 알 수 없습니다")));
end
function testTemplateCsvKeepsV2Path(t)
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_hppc_practice.csv'),uecm.defaults());
verifyFalse(t,isfield(i,'RawReport'));
end
% ------------------------------------------------------------------ time screens / HPPC rules
function testExactDuplicatesDroppedLosslessly(t)
tt=(0:20)';tt=[tt(1:5);tt(5);tt(6:end)];s=uecm.screenTimeSeries(tt,zeros(size(tt)),3.7*ones(size(tt)));
verifyFalse(t,s.Blocking);verifyEqual(t,s.Counts.exact_duplicates,1);
end
function testSameTimeDifferentValues(t)
tt=(0:20)';tt=[tt(1:5);tt(5);tt(6:end)];i=zeros(size(tt));v=3.7*ones(size(tt));v(6)=3.6;
s=uecm.screenTimeSeries(tt,i,v);verifyTrue(t,s.Blocking);verifyTrue(t,contains(s.Message,"시간 역전"));
o=uecm.defaults();o.DuplicateTimePolicy="keep_last";s=uecm.screenTimeSeries(tt,i,v,o);verifyFalse(t,s.Blocking);verifyTrue(t,s.Keep(6));
end
function testReloggedCopyAppended(t)
a=(0:0.1:10)';b=(0:1:15)';tt=[a;b];i=zeros(size(tt));v=3.7*ones(size(tt));
verifyTrue(t,uecm.screenTimeSeries(tt,i,v).Blocking);
o=uecm.defaults();o.TimeResetPolicy="keep_first_log";s=uecm.screenTimeSeries(tt,i,v,o);verifyEqual(t,tt(s.Keep),[a;(11:15)']);
end
function testSOCOvershootClippedNotDiscarded(t)
o=uecm.defaults();o.CurrentSign="discharge_positive";
i=uecm.readInput(fullfile(t.TestData.Root,'examples','SYNTHETIC_hppc_practice.csv'),o);
i.Data.soc_pct(1)=100.14;i.Data.soc_pct(2)=130;p=uecm.prepare(i);
verifyEqual(t,p.Data.soc(1),100);verifyTrue(t,isnan(p.Data.soc(2)));verifyEqual(t,sum(isfinite(p.Data.soc)),height(p.Data)-1);
end
function testRechargeStepIsNotRest(t)
tt=(0:0.1:200)';i=zeros(size(tt));i(tt>=20&tt<30)=36;i(tt>=50&tt<142)=-0.3;v=3.8-0.01*i;o=uecm.defaults();
f=uecm.fitHPPC(tt,i,v,o);verifyEqual(t,f{1}.Time(end),29.9,'AbsTol',1e-6);
o.MaxPulseDuration_s=60;verifyEqual(t,numel(uecm.fitHPPC(tt,i,v,o)),1);
end
function testOneSampleGlitchDoesNotCutRelaxation(t)
tt=(0:0.01:80)';i=zeros(size(tt));i(tt>=10&tt<20)=5;i(abs(tt-20.5)<0.004)=0.06;v=3.8-0.02*i;
f=uecm.fitHPPC(tt,i,v,uecm.defaults());verifyEqual(t,numel(f),1);verifyGreaterThan(t,f{1}.Time(end),60);
end
function testShortBlipAt1kHzDoesNotDropPulse(t)
% REAL Wuppertal MCU6, SOC 50 %: an 8 ms (8 samples at 1 kHz) +0.051 A blip right after the charge pulse.
% Count-only glitch rule (<5 samples) kept it as a pulse and the charge pulse lost its relaxation window (1 result).
% Only 2 pulses in this excerpt: the data-based sign rule needs >=3, so the sign is given as a user would.
o=uecm.defaults();o.CurrentSign="charge_positive";
i=uecm.readInput(fullfile(t.TestData.Fx,'wuppertal_50E_MCU6_REAL_excerpt_SOC50_glitch.csv'),o);
verifyEqual(t,i.RawReport.DroppedRows,2);
b=uecm.analyze(i);verifyEqual(t,height(b.Results),2);                 % discharge -4.9 A + charge +3.67 A
R0=zeros(1,2);
for k=1:2
    S=b.Fits{k}.Alternatives;names=cellfun(@(c)string(c.ModelName),S);
    R0(k)=S{names=="2RC"}.Parameters.R0_Ohm;
end
verifyEqual(t,R0,[0.017214 0.017323],'RelTol',0.03);
end
function testRampedPulseAccepted(t)
tt=(0:0.001:60)';i=zeros(size(tt));on=tt>=10&tt<20;i(on)=4.9*(1-exp(-(tt(on)-10)/0.002));v=3.8-0.02*i;
verifyEqual(t,numel(uecm.fitHPPC(tt,i,v,uecm.defaults())),1);
end
% ------------------------------------------------------------------ SOC from the record (full-charge anchor)
function testSOCAnchorSynthetic(t)
% SYNTHETIC: 1 A discharge to cutoff, rest, CC 1 A + CV taper to full, rest, then -1 A steps of 360 s.
dt=1;tt=(0:dt:30000)';i=zeros(size(tt));v=3.6*ones(size(tt));
d1=tt<3600;i(d1)=-1;v(d1)=3.6-0.0003*tt(d1);v(tt>=3600&tt<5400)=2.55;               % ends at the lowest voltage
cc=tt>=5400&tt<9000;i(cc)=1;v(cc)=linspace(3.0,4.2,sum(cc));
cv=tt>=9000&tt<10800;i(cv)=exp(-(tt(cv)-9000)/300);v(cv)=4.2;                       % taper to ~0.25 % of CC
r=tt>=10800&tt<12600;v(r)=4.18;
for k=0:4,s1=tt>=12600+k*1000&tt<12960+k*1000;i(s1)=-1;v(s1)=4.1-0.1*k;v(tt>=12960+k*1000&tt<13600+k*1000)=4.12-0.1*k;end
a=uecm.socFromAnchors(tt,i,v);
expectedCap=(3600+300*(1-exp(-1800/300)))/3600;                                       % CC + CV charge [Ah]
verifyTrue(t,a.Found);verifyEqual(t,a.Capacity_Ah,expectedCap,'RelTol',3e-3);   % current below the rest threshold is not counted
k=find(tt==12960+4*1000,1);verifyEqual(t,a.SOC(k),100-100*5*360/3600/expectedCap,'AbsTol',0.2);
end
function testSOCAnchorAbsentIsReported(t)
i=uecm.readInput(fullfile(t.TestData.Fx,'wuppertal_50E_MCU1_REAL_excerpt_HPPC1.csv'),uecm.defaults());
p=uecm.prepare(i);verifyTrue(t,any(contains(p.Notes,"완전 충전(CC-CV) 구간을 찾지 못했습니다")));
verifyTrue(t,all(isnan(p.Data.soc)));
end

