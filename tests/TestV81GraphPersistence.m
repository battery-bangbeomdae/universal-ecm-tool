classdef TestV81GraphPersistence < matlab.unittest.TestCase
    properties
        Input
        Bundle
    end
    methods(TestClassSetup)
        function fixture(t)
            root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
            o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
            t.Input=uecm.readInput(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'),o);t.Bundle=uecm.analyze(t.Input);
        end
    end
    methods(Test)
        function tabChangesDoNotHideMainMap(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");main=findall(a.view.UIFigure,'Tag','ParameterMap');panel=findall(a.view.UIFigure,'Tag','MainMapPanel');
            a.view.showStage("overlay");drawnow;t.verifyEqual(string(panel.Visible),"on");t.verifyNotEmpty(findall(main,'Type','scatter'));
            a.view.setFilePlotMode("combined");drawnow;t.verifyEqual(string(panel.Visible),"on");
            a.view.setFilePlotMode("split");drawnow;t.verifyEqual(string(panel.Visible),"on");
            a.view.expandOverlay(true);drawnow;t.verifyEqual(string(panel.Visible),"off");
            a.view.expandOverlay(false);drawnow;t.verifyEqual(string(panel.Visible),"on");t.verifyNotEmpty(findall(main,'Type','scatter'));
            t.verifyEqual(a.viewModel.Bundle.Results,t.Bundle.Results);
        end
        function refreshKeepsAxesAndCamera(t)
            f=uifigure('Visible','off');t.addTeardown(@()delete(f));g=uigridlayout(f);
            [a,~]=uecm.plotParameterFiles(g,t.Bundle,1:height(t.Bundle.Results),"soc_pct","temperature_C","Rs_Ohm","combined");
            view(a{1},[71,22]);
            [b,shown]=uecm.plotParameterFiles(g,t.Bundle,1:height(t.Bundle.Results),"soc_pct","temperature_C","Rs_Ohm","combined");
            t.verifyTrue(isvalid(a{1}));t.verifyEqual(b{1},a{1});t.verifyEqual(b{1}.View,[71,22]);t.verifyEqual(numel(shown),height(t.Bundle.Results));
        end
        function badFilterDoesNotEraseOldGraph(t)
            f=uifigure('Visible','off');t.addTeardown(@()delete(f));g=uigridlayout(f);
            [a,~]=uecm.plotParameterFiles(g,t.Bundle,1:height(t.Bundle.Results),"soc_pct","temperature_C","Rs_Ohm","combined");
            h=findall(a{1},'Tag','OverlayParameterSeries');before=h.XData;
            bad=struct('Filters',struct('Numeric',table("soh_pct",true,90,10,'VariableNames',{'field','enabled','minimum','maximum'})));
            t.verifyError(@()uecm.plotParameterFiles(g,t.Bundle,1:height(t.Bundle.Results),"soc_pct","temperature_C","Rs_Ohm","combined",bad),'uecm:MapFilter');
            t.verifyTrue(isvalid(a{1}));t.verifyTrue(isvalid(h));t.verifyEqual(h.XData,before);
        end
        function noneToYRestores3DOverlay(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            a.view.setAxes("soc_pct","none","Rs_Ohm");a.view.setFilePlotMode("combined");
            ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyEqual(ax.View,[0,90]);
            a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");new=findall(a.view.UIFigure,'Tag','MainParameterMap');
            t.verifyEqual(new,ax);t.verifyNotEqual(new.View,[0,90]);
            mode=findall(a.view.UIFigure,'Tag','OverlayMode');t.verifyEqual(string(mode.Value),"응답·잔차");t.verifyNotEqual(new.View,[0,90]);
            a.view.setOverlayModels(false);t.verifyTrue(isvalid(new));t.verifyNotEmpty(findall(new,'Tag','OverlayParameterSeries'));
        end
    end
end
