classdef TestV81FilePlots < matlab.unittest.TestCase
    properties
        Input
        Bundle
    end
    methods(TestClassSetup)
        function loadFiles(t)
            root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
            folder=string(tempname);mkdir(folder);t.addTeardown(@()rmdir(folder,'s'));
            a=fullfile(folder,'SYNTHETIC_first.csv');b=fullfile(folder,'SYNTHETIC_second.csv');
            copyfile(fullfile(root,'examples','SYNTHETIC_eis_practice.csv'),a);copyfile(a,b);
            o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
            t.Input=uecm.readInputs([a;b],o,"");t.Bundle=uecm.analyze(t.Input);
        end
    end
    methods(Test)
        function combinedPreservesAllPointsAndFiles(t)
            f=uifigure('Visible','off');t.addTeardown(@()delete(f));g=uigridlayout(f);
            [axesList,shown]=uecm.plotParameterFiles(g,t.Bundle,1:height(t.Bundle.Results),"soc_pct","temperature_C","Rs_Ohm","combined");
            t.verifyNumElements(axesList,1);t.verifyEqual(sort(shown),(1:height(t.Bundle.Results))');
            series=findall(axesList{1},'Tag','OverlayParameterSeries');t.verifyNumElements(series,2);
            t.verifyNotEqual(series(1).CData,series(2).CData);
            t.verifyEqual(axesList{1}.UserData.FitIndices,shown);
            t.verifyEqual(sum(arrayfun(@(h)numel(h.XData),series)),height(t.Bundle.Results));
        end
        function splitKeepsFilesSeparateAndScrollable(t)
            f=uifigure('Visible','off');t.addTeardown(@()delete(f));g=uigridlayout(f);
            [axesList,shown]=uecm.plotParameterFiles(g,t.Bundle,1:height(t.Bundle.Results),"soc_pct","temperature_C","Rs_Ohm","split");
            t.verifyNumElements(axesList,2);t.verifyEqual(string(g.Scrollable),"on");t.verifyEqual(g.RowHeight,{420,420});
            t.verifyNotEqual(axesList{1}.UserData.SourceFile,axesList{2}.UserData.SourceFile);
            t.verifyNumElements(findall(axesList{1},'Tag','OverlayParameterSeries'),1);t.verifyNumElements(findall(axesList{2},'Tag','OverlayParameterSeries'),1);
            t.verifyEqual(numel(shown),height(t.Bundle.Results));
        end
        function oneAxisUses2DAndSkipsMissingOnly(t)
            f=uifigure('Visible','off');t.addTeardown(@()delete(f));g=uigridlayout(f);b=t.Bundle;b.Results.soc_pct(1)=NaN;
            [axesList,shown]=uecm.plotParameterFiles(g,b,1:height(b.Results),"soc_pct","none","Rs_Ohm","combined");
            t.verifyEqual(axesList{1}.View,[0,90]);t.verifyEqual(numel(shown),height(b.Results)-1);t.verifyFalse(ismember(1,shown));
        end
        function uiScopeSwitchesAndReturns(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");a.view.setFilePlotMode("combined");drawnow;
            ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyNumElements(ax,1);t.verifyNotEqual(ax.View,[0,90]);
            t.verifyNumElements(findall(ax,'Tag','OverlayParameterSeries'),2);
            a.view.setFilePlotMode("split");drawnow;ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyNumElements(ax,2);
            g=findall(a.view.UIFigure,'Tag','MainMapPlotGrid');t.verifyEqual(g.RowHeight,{420,420});
            a.view.setFilePlotMode("single");drawnow;main=findall(a.view.UIFigure,'Tag','ParameterMap');t.verifyEqual(string(findall(a.view.UIFigure,'Tag','MainMapPanel').Visible),"on");
            t.verifyEqual(a.viewModel.Bundle.Results,t.Bundle.Results);
        end
    end
end
