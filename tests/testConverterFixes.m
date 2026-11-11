function tests=testConverterFixes
%TESTCONVERTERFIXES Fixes D, J, B, C to the raw-data converter (2026-11-07, instruction v2).
% All fixtures here are SYNTHETIC layout/physics checks written to a temporary folder; no measured values.
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
t.TestData.Fx=fullfile(t.TestData.Root,'tests','fixtures_raw');
end
function setup(t)
t.TestData.Dir=string(tempname);mkdir(t.TestData.Dir);
end
function teardown(t)
if isfolder(t.TestData.Dir),rmdir(t.TestData.Dir,'s');end
end

% ------------------------------------------------------------------ [D] EIS imaginary sign, physics check
function testFlippedImaginaryIsBlocked(t)
f=writeEIS(t,"flipped.csv",[1 -1],"Zimag [Ohm]");          % spectrum B written with the wrong sign
p=uecm.prepare(uecm.readInput(f,uecm.defaults()));
verifyTrue(t,p.Blocked);
r=p.Requests(p.Requests.Field=="imag_sign_physics",:);
verifyEqual(t,height(r),1);
verifyTrue(t,contains(r.Reason,"EIS 허수부 부호 이상 감지"));
verifyTrue(t,contains(r.Action,"B("));verifyFalse(t,contains(r.Action,"A("));   % per spectrum, names only B
end
function testCorrectImaginaryPasses(t)
f=writeEIS(t,"ok.csv",[1 1],"Zimag [Ohm]");
p=uecm.prepare(uecm.readInput(f,uecm.defaults()));
verifyFalse(t,any(p.Requests.Field=="imag_sign_physics"));
verifyTrue(t,all(p.Data.imag(p.Data.frequency>=0.1&p.Data.frequency<=100)<0));
end
function testImagSignCheckCanBeSwitchedOff(t)
f=writeEIS(t,"flipped_off.csv",[-1 -1],"Zimag [Ohm]");
o=uecm.defaults();o.ImagSignCheck="off";
p=uecm.prepare(uecm.readInput(f,o));
verifyFalse(t,any(p.Requests.Field=="imag_sign_physics"));
verifyTrue(t,any(contains(p.Notes,"ImagSignCheck = off")));
end
function testNegativeImaginaryColumnStillCorrect(t)
% '-Im(Z)' (EC-Lab) must keep its sign meaning after fix B: converted once, then passes the physics check
[T,r]=uecm.readRaw(fullfile(t.TestData.Fx,'eclab_EIS_SYNTHETIC_decimalcomma.mpt'));
verifyTrue(t,ismember("neg_im_z_ohm",string(T.Properties.VariableNames)));
verifyEqual(t,r.Mapping.source_column(r.Mapping.role=="neg_im_z_ohm"),"-Im(Z)/Ohm");
p=uecm.prepare(uecm.readInput(fullfile(t.TestData.Fx,'eclab_EIS_SYNTHETIC_decimalcomma.mpt'),uecm.defaults()));
verifyFalse(t,any(p.Requests.Field=="imag_sign_physics"));
end

% ------------------------------------------------------------------ [J] unsigned current + status column
function testUnsignedCurrentRebuiltFromStatus_TemplatePath(t)
f=writeUnsignedHPPC(t,"unsigned_tidy.csv",false,["D","C","R"]);
p=uecm.prepare(uecm.readInput(f,uecm.defaults()));
D=p.Data;src=readtable(f,'TextType','string');st=src.Status;
verifyGreaterThan(t,min(D.current(st=="D")),0);              % internal convention: discharge positive
verifyLessThan(t,max(D.current(st=="C")),0);
verifyFalse(t,any(ismember(p.Requests.Field,["current_sign","current_status","current_status_physics"])));
verifyTrue(t,any(contains(p.Notes,"상태 열")&contains(p.Notes,"복원")));
verifyTrue(t,any(contains(p.Notes,"펄스 시작 전압 변화와 일치")));   % ver_3: cross-check via inferPulseSign
end
function testUnsignedCurrentRawPath_ArbinStyleHeader(t)
% raw path (metadata line first) with Arbin-style names: exercises B (Test_Time(s)) and J together
f=writeUnsignedHPPC(t,"unsigned_raw.csv",true,["D","C","R"]);
[T,r]=uecm.readRaw(f);
verifyEqual(t,r.Kind,"HPPC");
verifyEqual(t,r.Mapping.source_column(r.Mapping.role=="time_s"),"Test_Time(s)");
verifyTrue(t,ismember("status_code",string(T.Properties.VariableNames)));
p=uecm.prepare(uecm.readInput(f,uecm.defaults()));
verifyFalse(t,any(ismember(p.Requests.Field,["current_sign","current_status","current_status_physics"])));
verifyGreaterThan(t,max(p.Data.current),0);verifyLessThan(t,min(p.Data.current),0);
end
function testStatusCodesSwappedAreBlockedByPhysics(t)
f=writeUnsignedHPPC(t,"swapped.csv",false,["C","D","R"]);   % C/D written the wrong way round
p=uecm.prepare(uecm.readInput(f,uecm.defaults()));
verifyTrue(t,any(p.Requests.Field=="current_status_physics"));verifyTrue(t,p.Blocked);
end
function testUnknownStatusCodeIsBlocked(t)
f=writeUnsignedHPPC(t,"unknown_code.csv",false,["D","C","X"]);
p=uecm.prepare(uecm.readInput(f,uecm.defaults()));
r=p.Requests(p.Requests.Field=="current_status",:);
verifyEqual(t,height(r),1);verifyTrue(t,contains(r.Reason,"X"));
end
function testSignedFileWithStatusIsUntouched(t)
% Digatron has a Status column but a SIGNED current: nothing is rebuilt, results as before
i=uecm.readInput(fullfile(t.TestData.Fx,'digatron_30T_25C_HPPC_first1100s.csv'),uecm.defaults());
verifyTrue(t,ismember("status_code",string(i.Data.Properties.VariableNames)));
verifyEqual(t,i.Settings.CurrentSign,"charge_positive");
p=uecm.prepare(i);
verifyFalse(t,any(contains(p.Notes,"상태 열(")));
end

% ------------------------------------------------------------------ [B] separator fallback
function testArbinNamesRecognisedOnlyInSecondPass(t)
f=fullfile(t.TestData.Dir,"arbin_names.csv");
L=["Arbin export";"Date_Time,Test_Time(s),Step_Index,Current(A),Voltage(V),Aux_Temperature_1(C)"];
for k=0:29,L(end+1)=sprintf("2026-11-07 10:00:%02d,%d,1,%.3f,3.700,25.0",k,k,0.0);end %#ok<AGROW>
writelines(L,f);
[T,r]=uecm.readRaw(f);
verifyEqual(t,r.Kind,"HPPC");
verifyEqual(t,r.Mapping.source_column(r.Mapping.role=="time_s"),"Test_Time(s)");
verifyEqual(t,r.Mapping.source_column(r.Mapping.role=="temperature_C"),"Aux_Temperature_1(C)");
% ver_3 normalises "_" to a space on the first pass (roleOf), so no second-pass note is expected.
verifyTrue(t,ismember("raw_step",string(T.Properties.VariableNames)));
end

% ------------------------------------------------------------------ [C] role-unit compatibility
function testTemperatureNamedTIsNotTime(t)
f=fullfile(t.TestData.Dir,"t_degc.csv");
L=["Rig A";"Time [s],T [°C],Current [A],Voltage [V]"];
for k=0:29,L(end+1)=sprintf("%d,25.1,0.000,3.700",k);end %#ok<AGROW>
writelines(L,f,'Encoding','UTF-8');
[~,r]=uecm.readRaw(f);
verifyEqual(t,r.Kind,"HPPC");
verifyEqual(t,r.Mapping.source_column(r.Mapping.role=="time_s"),"Time [s]");
verifyFalse(t,any(contains(r.Requests,"'time')의 열이 여러 개")));
verifyTrue(t,any(contains(r.Mapping.note,"역할–단위 불일치로 제외")&r.Mapping.source_column=="T [°C]"));
end
function testWrongUnitCancelsRole(t)
f=fullfile(t.TestData.Dir,"wrong_unit.csv");
L=["Rig B";"Time [s],Current [A],Voltage [A],Cell Voltage [V]"];
for k=0:29,L(end+1)=sprintf("%d,0.000,0.000,3.700",k);end %#ok<AGROW>
writelines(L,f);
[~,r]=uecm.readRaw(f);
verifyEqual(t,r.Mapping.source_column(r.Mapping.role=="voltage_V"),"Cell Voltage [V]");   % 'Voltage [A]' dropped
end

% ------------------------------------------------------------------ [G] sweep split (2026-11-09, hold-out findings)
function testSweepIndexCountsEachBoundaryOnce(t)
up=logspace(-1,4,41)';down=flipud(up);
verifyEqual(t,max(uecm.sweepIndex([up;up;up])),3);            % low->high (Zhu, Kiel): was 5 before the fix
verifyEqual(t,max(uecm.sweepIndex([down;down;down])),3);      % high->low (Zhang, Gamry)
s=uecm.sweepIndex([up;up]);verifyEqual(t,nnz(s==1),41);verifyEqual(t,nnz(s==2),41);   % no one-point spectrum
small=logspace(2,0,11)';verifyEqual(t,max(uecm.sweepIndex([small;small;small])),3);  % restart < 1.5 decades
verifyEqual(t,max(uecm.sweepIndex(up)),1);
end
function testTidyEISWithoutIdIsSplitIntoSweeps(t)
% tidy table (template path), 3 sweeps, no spectrum ID: must become 3 spectra, not one "single" spectrum
fr=logspace(4,-2,61)';w=2*pi*fr;Z=0.02+0.03./(1+1i*w*0.03*2);
L="Frequency [Hz],Zreal [Ohm],Zimag [Ohm]";
for k=1:3,for q=1:numel(fr),L(end+1)=sprintf("%.8g,%.8g,%.8g",fr(q),real(Z(q)),imag(Z(q)));end,end %#ok<AGROW>
f=fullfile(t.TestData.Dir,"three_sweeps_tidy.csv");writelines(L,f);
p=uecm.prepare(uecm.readInput(f,uecm.defaults()));
verifyFalse(t,p.Blocked);
verifyEqual(t,numel(unique(p.Data.spectrum)),3);
verifyTrue(t,any(contains(p.Notes,"스펙트럼 3개")));
end
function testTidyEISSingleSweepUnchanged(t)
f=writeEIS(t,"single_tidy.csv",1,"Zimag [Ohm]");             % has spectrum_id column -> untouched
p=uecm.prepare(uecm.readInput(f,uecm.defaults()));verifyEqual(t,numel(unique(p.Data.spectrum)),1);
L="Frequency [Hz],Zreal [Ohm],Zimag [Ohm]";fr=logspace(4,-2,61)';
for q=1:numel(fr),L(end+1)=sprintf("%.8g,0.03,%.8g",fr(q),-0.01);end %#ok<AGROW>
f2=fullfile(t.TestData.Dir,"single_noid.csv");writelines(L,f2);
p2=uecm.prepare(uecm.readInput(f2,uecm.defaults()));verifyEqual(t,unique(p2.Data.spectrum),"single");
end
function testExcelBlankHeaderCellNoWarning(t)
f=fullfile(t.TestData.Dir,"blank_header.xlsx");
C=[{'Frequency [Hz]','','Zreal [Ohm]','Zimag [Ohm]'};num2cell([logspace(3,-1,20)',zeros(20,1),0.03*ones(20,1),-0.01*ones(20,1)])];
writecell(C,f);
s=warning('error','uecm:HeaderRead');c=onCleanup(@()warning(s)); %#ok<NASGU>  % fallback warning -> test failure
i=uecm.readInput(f,uecm.defaults());
verifyGreaterThan(t,strlength(string(i.Mapping.frequency)),0);
end

% ------------------------------------------------------------------ mixed Excel workbook (Kiel hold-out, 2026-11-09)
function testMixedWorkbookFollowsAnalysisType(t)
% Arbin-type workbook: info sheet, channel time series, ACIM (EIS). Auto must stop; EIS/HPPC must pick that sheet.
f=fullfile(t.TestData.Dir,"mixed_arbin.xlsx");
writecell({'TEST REPORT'},f,'Sheet','Global_Info');
n=40;tt=(0:n-1)';writetable(table(tt,zeros(n,1),3.7*ones(n,1),'VariableNames',{'Test Time (s)','Current (A)','Voltage (V)'}),f,'Sheet','Channel-1_1');
fr=logspace(3,-1,21)';writetable(table(fr,0.03+0*fr,-0.01+0*fr,ones(21,1),'VariableNames',{'Frequency','Zreal','Zimg','EIS_Test_ID'}),f,'Sheet','ACIM_chan_1');
verifyError(t,@()uecm.readRaw(f,uecm.defaults()),'uecm:RawExcelMixed');
o=uecm.defaults();o.Type="EIS";[T,r]=uecm.readRaw(f,o);
verifyEqual(t,r.Kind,"EIS");verifyEqual(t,height(T),21);verifyTrue(t,any(contains(r.Hints,"Channel-1_1")));
o.Type="HPPC";[T,r]=uecm.readRaw(f,o);
verifyEqual(t,r.Kind,"HPPC");verifyEqual(t,height(T),n);
end

% ================================================================== synthetic fixture writers
function f=writeEIS(t,name,signs,imagHeader)
% Randles cell R0 + R1||C1: capacitive (Im<0) everywhere -> realistic sign pattern. signs(k)=-1 flips spectrum k.
fr=logspace(4,-2,61)';w=2*pi*fr;R0=0.020;R1=0.030;C1=2;
Z=R0+R1./(1+1i*w*R1*C1);ids=["A","B"];
L="spectrum_id,Frequency [Hz],Zreal [Ohm],"+imagHeader;
for k=1:numel(signs)
    for q=1:numel(fr),L(end+1)=sprintf("%s,%.8g,%.8g,%.8g",ids(k),fr(q),real(Z(q)),signs(k)*imag(Z(q)));end %#ok<AGROW>
end
f=fullfile(t.TestData.Dir,name);writelines(L,f);
end
function f=writeUnsignedHPPC(t,name,rawStyle,codes)
% codes = [discharge charge rest] labels written into the status column. Physics: V = 3.7 - R*I_dis.
% Pulses: 3 x (60 s rest, 10 s discharge 2 A, 60 s rest, 10 s charge 2 A), 1 s sampling, current written UNSIGNED.
R=0.02;I=[];S=strings(0,1);
for c=1:3
    seg={[60 0 3],[10 2 1],[60 0 3],[10 -2 2]};          % [duration, I_discharge_positive, code index]
    for s=1:numel(seg)
        d=seg{s}(1);I=[I;repmat(seg{s}(2),d,1)];S=[S;repmat(codes(seg{s}(3)),d,1)]; %#ok<AGROW>
    end
end
tt=(0:numel(I)-1)';V=3.7-R*I;
if rawStyle
    L=["Arbin-style export (synthetic)";"Test_Time(s),Current(A),Voltage(V),State"];
else
    L="Time [s],Current [A],Voltage [V],Status";
end
for k=1:numel(tt),L(end+1)=sprintf("%d,%.4f,%.5f,%s",tt(k),abs(I(k)),V(k),S(k));end %#ok<AGROW>
f=fullfile(t.TestData.Dir,name);writelines(L,f);
end
