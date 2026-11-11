function tests=testWarburgRecommendation
tests=functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));
end

function testDiffusionTieAndStrongSecondBranch(t)
f=logspace(4,-3,80)';
w=2*pi*f;
z=.01+.02./(1+1i*w*.02)+.001*(1-1i)./sqrt(w);
a=struct('Domain',"EIS",'Frequency',f,'Measured',z,'Predicted',z, ...
    'SourceIndices',(1:numel(f))','ModelName',"1RC+W",'NParameters',4, ...
    'ErrorUnit',"Ohm",'BIC',10,'Status',"candidate",'Condition',10,'ExitFlag',1, ...
    'Parameters',struct('Warburg_sigma_Ohm_s_mhalf',.001));
b=a;b.ModelName="2RC";b.NParameters=5;b.BIC=7;
result=uecm.compareCandidates({a,b});
verifyEqual(t,result.ModelName,"1RC+W");
b.BIC=3;
result=uecm.compareCandidates({a,b});
verifyEqual(t,result.ModelName,"2RC");
b.Parameters.tau2_s=100;
result=uecm.compareCandidates({a,b});
verifyEqual(t,result.ModelName,"1RC+W");
a.Measured=.01+.02./(1+1i*w*.02);b.Measured=a.Measured;
a.Predicted=a.Measured;b.Predicted=a.Measured;b.BIC=7;
result=uecm.compareCandidates({a,b});
verifyEqual(t,result.ModelName,"2RC");
end

function testSyntheticFits(t)
f=logspace(4,-3,80)';
w=2*pi*f;
o=uecm.defaults();o.EISModels=["RC","2RC"];
z=.01+.02./(1+1i*w*.02)+.001*(1-1i)./sqrt(w);
result=uecm.fitEIS(f,real(z),imag(z),o);
verifyEqual(t,result.ModelName,"1RC+W");
z=.01+.02./(1+1i*w*.02)+.035./(1+1i*w*2);
result=uecm.fitEIS(f,real(z),imag(z),o);
verifyEqual(t,result.ModelName,"2RC");
o.EISModels=["CPE","2CPE"];
z=.01+.02./(1+(1i*w*.02).^.8)+.001*(1-1i)./sqrt(w);
result=uecm.fitEIS(f,real(z),imag(z),o);
verifyEqual(t,result.ModelName,"CPE+W");
end
