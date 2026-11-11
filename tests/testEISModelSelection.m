function tests=testEISModelSelection
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.Root);
end
function testOnlyRequestedFamiliesAndWarburg(t)
o=uecm.defaults();o.EISModels=["RC","CPE"];o.EISAutoWarburg=false;
verifyEqual(t,uecm.eisFitTypes(o),["RC","CPE"]);
o.EISAutoWarburg=true;verifyEqual(t,uecm.eisFitTypes(o),["RC","RC+W","CPE","CPE+W"]);
o.EISModels=strings(1,0);verifyError(t,@()uecm.eisFitTypes(o),'uecm:EISModels');
end
function testLegacySettings(t)
o=struct('Circuit',"2CPE+W");verifyEqual(t,uecm.eisFitTypes(o),["2CPE","2CPE+W"]);
o.Circuit="RC";verifyEqual(t,uecm.eisFitTypes(o),"RC");
end
function testFitSkipsUncheckedModels(t)
f=logspace(3,-2,35)';z=.01+.03./(1+1i*2*pi*f*2);
o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
r=uecm.fitEIS(f,real(z),imag(z),o);
verifyEqual(t,r.EvaluatedModels,"RC");c=uecm.candidatesOf(r);
verifyEqual(t,numel(c),1);verifyEqual(t,c{1}.Candidate,"RC");
end
function testCheckboxesUpdateSettings(t)
a=launch_universal_ecm();cleanup=onCleanup(@()delete(a.view));
for name=["2RC","CPE","2CPE"]
 c=findall(a.view.UIFigure,'Tag',"EISModel_"+name);c.Value=false;feval(c.ValueChangedFcn,c,[]);
end
w=findall(a.view.UIFigure,'Tag','EISAutoWarburg');w.Value=false;feval(w.ValueChangedFcn,w,[]);
verifyEqual(t,a.viewModel.Settings.EISModels,"RC");
verifyFalse(t,a.viewModel.Settings.EISAutoWarburg);
verifyEqual(t,a.viewModel.Settings.Circuit,"auto");
a.viewModel.Busy=true;verifyEqual(t,string(w.Enable),"off");
a.viewModel.Busy=false;verifyEqual(t,string(w.Enable),"on");
end
