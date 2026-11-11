function tests=testResearchUnits
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
end
function testPrefixCaseAndDimensions(t)
milli=uecm.unitDefinition("mHz","frequency");mega=uecm.unitDefinition("MHz","frequency");
verifyEqual(t,milli.Factor,1e-3);verifyEqual(t,mega.Factor,1e6);
micro=uecm.unitDefinition("µΩ","impedance");verifyEqual(t,micro.Factor,1e-6);
wrong=uecm.unitDefinition("Hz","current");verifyFalse(t,wrong.Known);
kelvin=uecm.unitDefinition("K","temperature");verifyEqual(t,kelvin.Offset,-273.15);
end
function testRawPhaseAndTemperatureKeepTheirPhysicalValues(t)
folder=string(tempname);mkdir(folder);c=onCleanup(@()rmdir(folder,'s'));
file=fullfile(folder,"raw.txt");
fid=fopen(file,'w');closer=onCleanup(@()fclose(fid));
fprintf(fid,'Instrument export\nFrequency [mHz]\tMagnitude [mOhm]\tPhase [rad]\tTemperature [K]\n');
fprintf(fid,'%.12g\t100\t%.15g\t298.15\n', [logspace(0,3,20);repmat(-pi/4,1,20)]);
clear closer
input=uecm.readInput(file);p=uecm.prepare(input);
verifyFalse(t,p.Blocked);
verifyEqual(t,p.Data.frequency,logspace(0,3,20)'/1000,'RelTol',1e-10);
verifyEqual(t,p.Data.real,repmat(.1/sqrt(2),20,1),'AbsTol',1e-12);
verifyEqual(t,p.Data.imag,repmat(-.1/sqrt(2),20,1),'AbsTol',1e-12);
verifyEqual(t,p.Data.temperature,repmat(25,20,1),'AbsTol',1e-12);
end
