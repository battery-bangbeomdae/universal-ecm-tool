classdef TestV81QueuedClose < matlab.uitest.TestCase
    methods(TestClassSetup)
        function path(t)
            root=fileparts(fileparts(mfilename('fullpath')));addpath(root); %#ok<NASGU>
        end
    end
    methods(Test)
        function exitButtonStaysEnabledWhileBusyAndPressCloses(t)
            a=launch_universal_ecm();t.addTeardown(@()safeDelete(a.view));fig=a.view.UIFigure;
            a.viewModel.Busy=true;button=findall(fig,'Tag','ECMExitButton');
            t.verifyEqual(string(button.Enable),"on");
            t.press(button);drawnow;
            t.verifyFalse(isvalid(fig));t.verifyFalse(isvalid(a.view));t.verifyFalse(a.viewModel.Busy);
        end
        function nativeCloseRouteIsSharedAndStillWorks(t)
            a=launch_universal_ecm();t.addTeardown(@()safeDelete(a.view));fig=a.view.UIFigure;
            t.verifyEqual(string(fig.Tag),"UniversalECMMainWindow");
            close(fig);drawnow;t.verifyFalse(isvalid(fig));t.verifyFalse(isvalid(a.view));
        end
        function recoveryClosesOnlyECMWindow(t)
            other=uifigure('Visible','off','Name','Unrelated figure');t.addTeardown(@()safeDelete(other));
            a=launch_universal_ecm();t.addTeardown(@()safeDelete(a.view));fig=a.view.UIFigure;
            fig.CloseRequestFcn=@(~,~)[];
            count=close_universal_ecm();
            t.verifyEqual(count,1);t.verifyFalse(isvalid(fig));t.verifyFalse(isvalid(a.view));t.verifyTrue(isvalid(other));
        end
        function queuedCloseRunsInsideAxisInventory(t)
            a=launch_universal_ecm();t.addTeardown(@()safeDelete(a.view));fig=a.view.UIFigure;
            clock=timer('ExecutionMode','singleShot','StartDelay',0,'TimerFcn',@(~,~)safeClose(fig));t.addTeardown(@()delete(clock));start(clock);
            A=uecm.axisInventory(struct(),"*",@()pump(fig));
            t.verifyEmpty(A);t.verifyFalse(isvalid(fig));t.verifyFalse(isvalid(a.view));
        end
        function queuedCloseRunsInsideParameterPlot(t)
            f=uifigure('Visible','off');t.addTeardown(@()safeDelete(f));g=uigridlayout(f,[1,1]);f.UserData=0;
            R=table("a.csv",50,25,.01,'VariableNames',{'source_file','soc_pct','temperature_C','Rs_Ohm'});
            fit=struct('Parameters',struct('Rs_Ohm',.01));b=struct('Results',R,'Fits',{{fit}});
            clock=timer('ExecutionMode','singleShot','StartDelay',0,'TimerFcn',@(~,~)safeClose(f));t.addTeardown(@()delete(clock));
            [axesList,shown]=uecm.plotParameterFiles(g,b,1,"soc_pct","temperature_C","Rs_Ohm","combined",struct('ContinueFcn',@()pumpOnThird(f,clock)));
            t.verifyEmpty(axesList);t.verifyEmpty(shown);t.verifyFalse(isvalid(f));
        end
    end
end
function alive=pump(fig)
drawnow;alive=isvalid(fig);
end
function safeClose(fig)
if isvalid(fig),close(fig);end
end
function safeDelete(obj)
if isvalid(obj),delete(obj);end
end

function alive=pumpOnThird(fig,clock)
fig.UserData=fig.UserData+1;
if fig.UserData==3,start(clock);end
drawnow;alive=isvalid(fig);
end
