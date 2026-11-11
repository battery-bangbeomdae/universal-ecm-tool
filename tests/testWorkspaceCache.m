function tests=testWorkspaceCache
tests=functiontests(localfunctions);
end
function testAppendBackupReset(testCase)
root=fileparts(fileparts(mfilename('fullpath')));d=string(tempname);mkdir(d);cleanup=onCleanup(@()rmdir(d,'s')); %#ok<NASGU>
copyfile(fullfile(root,'examples','REAL_D014_hppc_one_pulse.csv'),fullfile(d,'a.csv'));copyfile(fullfile(d,'a.csv'),fullfile(d,'b.csv'));
T=readtable(fullfile(d,'a.csv'));T.laboratory_step=(1:height(T))';writetable(T,fullfile(d,'a.csv'));copyfile(fullfile(d,'a.csv'),fullfile(d,'b.csv'));
o=uecm.defaults();o.Type="HPPC";o.CurrentSign="charge_positive";
x=uecm.workspaceLoad(fullfile(d,'a.csv'),o,"",struct(),struct());
b=uecm.workspaceFit(x.Input,struct(),true,@(~)[]);verifyNotEmpty(testCase,b.Results);verifyEmpty(testCase,b.CacheWarnings);direct=uecm.analyze(x.Input,@(~)[],x.Bundle.Prepared);verifyEqual(testCase,b.Results,direct.Results);
y=uecm.workspaceLoad(fullfile(d,'b.csv'),o,"",x.Input,b);verifyEqual(testCase,numel(y.Input.OriginalInputs),2);verifyEqual(testCase,height(y.Bundle.Results),height(b.Results));
z=uecm.workspaceLoad(fullfile(d,'a.csv'),o,"",struct(),struct());verifyEqual(testCase,z.Bundle.Results,b.Results);
w=uecm.workspaceLoad(fullfile(d,'a.csv'),o,"",y.Input,y.Bundle);verifyEqual(testCase,numel(w.Input.OriginalInputs),2);
changed=o;changed.Circuit="2RC";miss=uecm.workspaceLoad(fullfile(d,'a.csv'),changed,"",struct(),struct());verifyEmpty(testCase,miss.Bundle.Results);
T=readtable(fullfile(d,'a.csv'));vars=string(T.Properties.VariableNames);v=find(contains(lower(vars),'voltage'),1);if ~isempty(v),T.(vars(v))(1)=T.(vars(v))(1)+.01;writetable(T,fullfile(d,'a.csv'));end
miss=uecm.workspaceLoad(fullfile(d,'a.csv'),o,"",struct(),struct());if ~isempty(v),verifyEmpty(testCase,miss.Bundle.Results);end
m=uecm.Models.SessionModel();vm=uecm.ViewModels.MainViewModel(m);vm.acceptWorkspace(y.Input,y.Bundle);vm.resetWorkspace();verifyEmpty(testCase,fieldnames(vm.Input));verifyNotEmpty(testCase,dir(fullfile(d,'ecm_result','**','fit_*.mat')));
end
function testEISRoundTrip(testCase)
root=fileparts(fileparts(mfilename('fullpath')));d=string(tempname);mkdir(d);cleanup=onCleanup(@()rmdir(d,'s')); %#ok<NASGU>
T=readtable(fullfile(root,'examples','REAL_D010_eis_12spectra.csv'),'TextType','string');T=T(T.spectrum_id==T.spectrum_id(1),:);writetable(T,fullfile(d,'eis.csv'));
o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
x=uecm.workspaceLoad(fullfile(d,'eis.csv'),o,"",struct(),struct());b=uecm.workspaceFit(x.Input,struct(),true,@(~)[]);verifyEqual(testCase,height(b.Results),1);
z=uecm.workspaceLoad(fullfile(d,'eis.csv'),o,"",struct(),struct());verifyEqual(testCase,z.Bundle.Results,b.Results);
copyfile(fullfile(root,'examples','REAL_D014_hppc_one_pulse.csv'),fullfile(d,'hppc.csv'));h=o;h.CurrentSign="charge_positive";
y=uecm.workspaceLoad(fullfile(d,'hppc.csv'),h,"",z.Input,z.Bundle);b2=uecm.workspaceFit(y.Input,y.Bundle,true,@(~)[]);verifyEqual(testCase,height(b2.Results),2);verifyEqual(testCase,numel(unique(b2.Results.domain)),2);
end
function testManualBackupRestore(testCase)
root=fileparts(fileparts(mfilename('fullpath')));d=string(tempname);mkdir(d);cleanup=onCleanup(@()rmdir(d,'s')); %#ok<NASGU>
copyfile(fullfile(root,'examples','REAL_D014_hppc_one_pulse.csv'),fullfile(d,'a.csv'));o=uecm.defaults();o.CurrentSign="charge_positive";o.EISModels="RC";
x=uecm.workspaceLoad(fullfile(d,'a.csv'),o,"",struct(),struct());b=uecm.workspaceFit(x.Input,struct(),true,@(~)[]);files=dir(fullfile(d,'ecm_result','**','fit_*.mat'));
y=uecm.workspaceLoad(string(fullfile(files(1).folder,files(1).name)),uecm.defaults(),"",struct(),struct());verifyEqual(testCase,y.Bundle.Results,b.Results);verifyEqual(testCase,y.Input.Settings.EISModels,"RC");
end
function testMovedPackageRestoresFitsWithCurrentConditions(testCase)
root=fileparts(fileparts(mfilename('fullpath')));parent=string(tempname);mkdir(parent);cleanup=onCleanup(@()rmdir(parent,'s')); %#ok<NASGU>
a=fullfile(parent,'old');mkdir(fullfile(a,'studies','S','experiments','E'));e=fullfile(a,'studies','S','experiments','E');
T=readtable(fullfile(root,'examples','REAL_D010_eis_12spectra.csv'),'TextType','string');T=T(T.spectrum_id==T.spectrum_id(1),:);
if ismember('soh_pct',T.Properties.VariableNames),T.soh_pct=[];end;writetable(T,fullfile(e,'signals.csv'));
M=table(T.spectrum_id(1),90,'VariableNames',{'spectrum_id','soh_pct'});writetable(M,fullfile(e,'measurements.csv'));
manifest=table("studies/S/experiments/E/signals.csv","studies/S/experiments/E/measurements.csv",'VariableNames',{'signal_file','conditions_file'});writetable(manifest,fullfile(a,'manifest.csv'));
o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
x=uecm.workspaceLoad(fullfile(a,'studies','S'),o,"",struct(),struct());b=uecm.workspaceFit(x.Input,struct(),true,@(~)[]);verifyEqual(testCase,height(b.Results),1);
z=fullfile(parent,'new');movefile(a,z);M.soh_pct=95;writetable(M,fullfile(z,'studies','S','experiments','E','measurements.csv'));
o.ImportMode="raw";y=uecm.workspaceLoad(fullfile(z,'studies','S','experiments','E'),o,"",struct(),struct());
verifyEqual(testCase,height(y.Bundle.Results),1);verifyEqual(testCase,y.Bundle.Results.Rs_Ohm,b.Results.Rs_Ohm);verifyEqual(testCase,y.Bundle.Results.soh_pct,95);
verifyEqual(testCase,y.Bundle.Fits{1}.Identity.soh_pct,95);
end
