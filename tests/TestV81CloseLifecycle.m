classdef TestV81CloseLifecycle < matlab.unittest.TestCase
    methods(TestClassSetup)
        function path(t)
            root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fullfile(root,'tests')); %#ok<NASGU>
        end
    end
    methods(Test)
        function cancellationFailureIsIsolated(t)
            bad=uecmtest.CancelProbe(true);good=uecmtest.CancelProbe(false);gone=uecmtest.CancelProbe(false);delete(gone);
            messages=uecm.cancelForClose({[],bad,good,gone});
            t.verifyEqual(numel(messages),1);t.verifyTrue(contains(messages,'uecmtest:CancelFailure'));
            t.verifyEqual(good.Calls,1);t.verifyEqual(bad.Calls,1);
        end
        function closeButtonDeletesOwnerAndAuxiliaryWindows(t)
            a=launch_universal_ecm();fig=a.view.UIFigure;v=a.viewModel;
            a.view.showStage("inputs");aux=findall(groot,'Tag','InputInformationWindow');
            close(fig);drawnow;
            t.verifyFalse(isvalid(fig));t.verifyFalse(isvalid(a.view));t.verifyFalse(any(isvalid(aux)));
            t.verifyFalse(v.Busy);t.verifyTrue(isvalid(v));
            v.Status="closed view observers detached";t.verifyEmpty(findall(groot,'Tag','InputInformationWindow'));
        end
        function directFigureDeletionCleansOwner(t)
            a=launch_universal_ecm();fig=a.view.UIFigure;
            delete(fig);drawnow;t.verifyFalse(isvalid(a.view));t.verifyFalse(isvalid(fig));
            t.verifyFalse(a.viewModel.Busy);
        end
        function closingDuringOwnedLoadDoesNotReopenWindows(t)
            a=launch_universal_ecm();fig=a.view.UIFigure;
            a.view.loadExample("eis");t.verifyTrue(a.viewModel.Busy);
            started=tic;close(fig);elapsed=toc(started);pause(.3);drawnow;
            t.verifyFalse(isvalid(fig));t.verifyFalse(isvalid(a.view));t.verifyFalse(a.viewModel.Busy);
            t.verifyLessThan(elapsed,10);t.verifyEmpty(findall(groot,'Tag','InputInformationWindow'));
        end
        function closeCanInterruptResultRefresh(t)
            root=fileparts(fileparts(mfilename('fullpath')));o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
            i=uecm.readInput(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'),o);b=uecm.analyze(i);
            a=launch_universal_ecm();a.viewModel.acceptInput(i);fig=a.view.UIFigure;
            timerObj=timer('ExecutionMode','singleShot','StartDelay',0,'TimerFcn',@(~,~)closeIfAlive(fig));
            t.addTeardown(@()delete(timerObj));start(timerObj);
            a.viewModel.acceptFit(b);drawnow;
            t.verifyFalse(isvalid(fig));t.verifyFalse(isvalid(a.view));t.verifyEqual(a.viewModel.Bundle.Results,b.Results);
        end
    end
end
function closeIfAlive(fig)
if isvalid(fig),close(fig);end
end
