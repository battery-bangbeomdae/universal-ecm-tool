classdef TestV81VariableJoinKeys < matlab.unittest.TestCase
    methods(Test)
        function commonIdentitiesGuardFitIdsAcrossChangedPaths(t)
            root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
            R=table(["f1";"f2"],["/new/a.csv";"/new/a.csv"],["S";"S"],["C1";"C2"],["T";"T"],["A";"B"], ...
                'VariableNames',{'fit_id','source_file','source_id','cell_id','test_id','spectrum_id'});
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));m.Bundle=struct('Results',R,'Fits',{{}});
            M=R;M.source_file(:)="/old/a.csv";M.dose=[10;20];p=uecm.Views.VariableImportView(v,M,"user.csv");t.addTeardown(@()safeDelete(p));
            keys=findall(p.UIFigure,'Tag','VariableJoinKey');path=keys(arrayfun(@(h)string(h.UserData)=="source_file",keys));
            t.verifyFalse(path.Value);t.verifyEqual(sum([keys.Value]),5);
            p.setSelectedColumns("dose");p.apply();t.verifyFalse(isvalid(p));t.verifyEqual(v.Bundle.Results.custom_dose,[10;20]);t.verifyEqual(v.Bundle.Results.source_file,R.source_file);
        end
    end
end
function safeDelete(p)
if isvalid(p),delete(p);end
end
