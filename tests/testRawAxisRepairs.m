function tests=testRawAxisRepairs
tests=functiontests(localfunctions);
end
function setup(t)
addpath(fileparts(fileparts(mfilename('fullpath'))));t.TestData.Dir=string(tempname);mkdir(t.TestData.Dir);t.addTeardown(@()rmdir(t.TestData.Dir,'s'));
end
function testNativeKITConditionsStayDifferentFromCapacitySOHAndCycle(t)
r=fullfile(t.TestData.Dir,'D009_KIT_NMC_CSiO');mkdir(r);file=fullfile(r,'cell_eisv2_test.csv');
writelines(["timestamp_s;soc_nom;t_avg_degC;freq_Hz;z_amp_mOhm;z_ph_deg;soh_imp;cyc_charged"; ...
 "1700000000;10;25;10;20;-30;99;1";"1700000000;10;25;1;30;-20;99;1"; ...
 "1700001000;90;40;10;15;-30;95;0";"1700001000;90;40;1;25;-20;95;0"],file);
o=uecm.defaults();o.ImportMode="raw";o.Type="EIS";i=uecm.readInput(file,o);p=uecm.prepare(i);
verifyFalse(t,p.Blocked);verifyEqual(t,p.Data.soc,[10;10;90;90]);verifyEqual(t,p.Data.temperature,[25;25;40;40]);
verifyEqual(t,numel(unique(p.Data.spectrum)),2);verifyTrue(t,all(isnan(p.Data.soh)));verifyTrue(t,all(isnan(p.Data.cycle)));verifyTrue(t,all(isnan(p.Data.calendar)));
verifyEqual(t,p.Data.real(1),.02*cosd(-30),'AbsTol',1e-14);
end
function testArbinCelsiusEncodingAndAmbiguousChannels(t)
f=fullfile(t.TestData.Dir,'raw.csv');o=uecm.defaults();o.ImportMode="raw";o.Type="HPPC";o.CurrentSign="charge_positive";
writelines(["Time(s),Current(A),Voltage(V),Aux_Temperature(¡æ)_1";"0,0,4,21.5";"1,-1,3.9,21.6"],f);
i=uecm.readInput(f,o);p=uecm.prepare(i);verifyFalse(t,p.Blocked);verifyEqual(t,p.Data.temperature,[21.5;21.6]);
writelines(["Time(s),Current(A),Voltage(V),Aux_Temperature(¡æ)_1,Aux_Temperature(¡æ)_2";"0,0,4,21.5,22.5";"1,-1,3.9,21.6,22.6"],f);
i=uecm.readInput(f,o);p=uecm.prepare(i);verifyTrue(t,all(isnan(p.Data.temperature)));
verifyTrue(t,ismember('Aux_Temperature(¡æ)_1',i.Data.Properties.VariableNames));
i.Mapping.temperature="Aux_Temperature(¡æ)_1";i.Settings.TemperatureUnit="C";p=uecm.prepare(i);verifyEqual(t,p.Data.temperature,[21.5;21.6]);
end
function testMeasuredSOHAboveInitialReferenceAndInvalidRowsStayLocal(t)
i=uecm.readInput(fullfile(fileparts(fileparts(mfilename('fullpath'))),'examples','SYNTHETIC_eis_practice.csv'));
i.Data.soh_pct(:)=100.27015437392795;i.Mapping.soh="soh_pct";i.Data.soc_pct(1)=101;
p=uecm.prepare(i);verifyFalse(t,p.Blocked);verifyEqual(t,p.Data.soh(1),100.27015437392795);
verifyTrue(t,isnan(p.Data.soc(1)));verifyTrue(t,all(isfinite(p.Data.soc(2:end))));
verifyTrue(t,any(p.Requests.Field=="soh_reference"));verifyEqual(t,uecm.validateConditionValue("soh_pct",100.27),100.27);
end
