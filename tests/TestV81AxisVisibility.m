classdef TestV81AxisVisibility < matlab.unittest.TestCase
    properties
        Root
        Input
        Bundle
    end
    methods(TestClassSetup)
        function loadFixture(t)
            t.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.Root);
            o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
            t.Input=uecm.readInput(fullfile(t.Root,'examples','SYNTHETIC_eis_practice.csv'),o);
            t.Bundle=uecm.analyze(t.Input);
        end
    end
    methods(Test)
        function missingPartialConstantAndEmpty(t)
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));
            b=t.Bundle;b.Results.soc_pct(2:end)=NaN;b.Results.temperature_C(:)=25;
            b.Results.soh_pct(:)=NaN;b.Results.calendar_days=repmat("",height(b.Results),1);m.Bundle=b;
            [f,~]=v.availableAxisChoices();
            t.verifyTrue(ismember("soc_pct",f));t.verifyTrue(ismember("temperature_C",f));
            t.verifyFalse(ismember("soh_pct",f));t.verifyFalse(ismember("calendar_days",f));
            t.verifyEqual(v.Bundle.Results,b.Results);
        end
        function fileSpecificAvailability(t)
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));
            b=t.Bundle;b.Results.source_file(1)="second.csv";b.Results.soh_pct(:)=NaN;b.Results.soh_pct(1)=80;m.Bundle=b;
            [f,~]=v.availableAxisChoices("second.csv");t.verifyTrue(ismember("soh_pct",f));
            [f,~]=v.availableAxisChoices(string(t.Input.File));t.verifyFalse(ismember("soh_pct",f));
            [f,~]=v.availableAxisChoices("missing.csv");t.verifyEmpty(f);
        end
        function parameterValuesFollowSelectedModel(t)
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));m.Bundle=t.Bundle;
            p=v.parameterChoices();t.verifyTrue(ismember("Rs_Ohm",p));t.verifyFalse(ismember("R2_Ohm",p));
            t.verifyEmpty(v.parameterChoices("2RC"));
        end
        function gui2D3DAndFallback(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            a.view.setAxes("soc_pct","none","Rs_Ohm");
            ax=findall(a.view.UIFigure,'Tag','ParameterMap');y=findall(a.view.UIFigure,'Tag','YAxisChoice');rot=findall(a.view.UIFigure,'Tag','RotateMap');
            t.verifyEqual(ax.View,[0,90]);t.verifyEqual(string(y.Value),"none");t.verifyEqual(string(rot.Enable),"off");
            sc=findall(ax,'Type','scatter');t.verifyEqual(sc.XData(:),t.Bundle.Results.soc_pct);t.verifyEqual(sc.YData(:),t.Bundle.Results.Rs_Ohm);t.verifyNotEmpty(sc.ButtonDownFcn);
            a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");t.verifyNotEqual(ax.View,[0,90]);t.verifyEqual(string(rot.Enable),"on");
            a.view.setAxes("temperature_C","soc_pct","Rs_Ohm");t.verifyEqual(string(y.Value),"soc_pct");t.verifyNotEqual(ax.View,[0,90]);
            a.view.setAxes("soc_pct","missing_old_session_axis","Rs_Ohm");t.verifyEqual(string(y.Value),"none");t.verifyEqual(ax.View,[0,90]);
            t.verifyEqual(a.viewModel.Bundle.Results,t.Bundle.Results);
        end
        function guiOnlyOneAxisAndNoAxes(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);
            b=t.Bundle;b.CustomAxes=b.CustomAxes([]);b.Results.temperature_C(:)=NaN;b.Results.cycle_number(:)=NaN;b.Results.initial_capacity_Ah(:)=NaN;b.Results.current_capacity_Ah(:)=NaN;a.viewModel.acceptFit(b);
            x=findall(a.view.UIFigure,'Tag','XAxisChoice');y=findall(a.view.UIFigure,'Tag','YAxisChoice');
            t.verifyEqual(string(x.ItemsData),"soc_pct");t.verifyEqual(string(y.Value),"none");
            b.Results.soc_pct(:)=NaN;a.viewModel.acceptFit(b);
            t.verifyEqual(string(x.Enable),"off");t.verifyEqual(string(y.Enable),"off");
        end
        function chartDropsOnlyMissingSelectedValues(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);
            b=t.Bundle;b.Results.soc_pct(1)=NaN;b.Results.temperature_C(2)=NaN;a.viewModel.acceptFit(b);
            [R,idx,~]=a.viewModel.chartData("soc_pct","none","Rs_Ohm","모두 (점으로 비교)","모두 (주의 포함)","권장 모델","3D");
            t.verifyEqual(height(R),height(b.Results)-1);t.verifyFalse(ismember(1,idx));t.verifyTrue(ismember(2,idx));
            [R,idx,~]=a.viewModel.chartData("soc_pct","temperature_C","Rs_Ohm","모두 (점으로 비교)","모두 (주의 포함)","권장 모델","3D");
            t.verifyEqual(height(R),height(b.Results)-2);t.verifyFalse(any(ismember([1,2],idx)));
        end
        function overlayGraphsFirstAndLive(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            a.view.setOverlaySelection(1,true);a.view.setOverlayMode("응답·잔차");a.view.showStage("overlay");drawnow;
            g=findall(a.view.UIFigure,'Tag','OverlayScrollLayout');host=findall(a.view.UIFigure,'Tag','OverlayGraphHost');
            t.verifyEqual(string(g.Scrollable),"on");t.verifyEqual(host.Layout.Row,1);t.verifyGreaterThanOrEqual(g.RowHeight{1},760);
            plots=findall(a.view.UIFigure,'Tag','SelectedExperimentPlots');t.verifyEqual(plots.ColumnWidth,{'1x','1x'});
            e=findall(a.view.UIFigure,'Tag','OverlayEISResponse');h=findall(a.view.UIFigure,'Tag','OverlayHPPCResponse');
            t.verifyEqual(e.Layout.Column,[1,2]);t.verifyEqual(string(e.Visible),"on");t.verifyEqual(string(h.Visible),"off");t.verifyNotEmpty(findall(e,'Tag','SelectedMeasured'));
            t.verifyEqual(a.view.selectedOverlayExperiments(),(1:height(t.Bundle.Results))');t.verifyEqual(a.viewModel.Bundle.Results,t.Bundle.Results);
        end
        function sessionRestoreAndDifferentFileAxes(t)
            folder=string(tempname);mkdir(folder);t.addTeardown(@()rmdir(folder,'s'));
            first=fullfile(folder,'SYNTHETIC_first.csv');second=fullfile(folder,'SYNTHETIC_second.csv');
            copyfile(fullfile(t.Root,'examples','SYNTHETIC_eis_practice.csv'),first);copyfile(first,second);
            o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
            i=uecm.readInputs([first;second],o,"");b=uecm.analyze(i);
            secondRows=string(b.Results.source_file)==second;index=find(secondRows,1);
            b.Results.soh_pct(:)=NaN;b.Results.soh_pct(secondRows)=80;
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(i);a.viewModel.acceptFit(b);a.viewModel.selectFit(index);
            a.view.setAxes("soh_pct","none","Rs_Ohm");x=findall(a.view.UIFigure,'Tag','XAxisChoice');
            t.verifyTrue(ismember('soh_pct',x.ItemsData));t.verifyEqual(string(x.Value),"soh_pct");
            a.viewModel.selectFit(1);t.verifyFalse(ismember('soh_pct',x.ItemsData));t.verifyNotEqual(string(x.Value),"soh_pct");
            a.viewModel.selectFit(index);a.view.setAxes("soh_pct","none","Rs_Ohm");
            settings=struct('X',"soh_pct",'Y',"none",'Z',"Rs_Ohm",'PlotDimension',"2D",'SelectedFit',index,'Rotate',true,'CameraView',[-37.5,30]);
            out=uecm.exportBundle(b,folder,settings);
            a.view.loadSaved(fullfile(out,'session.mat'));waitUntil(@()~a.viewModel.Busy,120);
            t.verifyEqual(string(x.Value),"soh_pct");y=findall(a.view.UIFigure,'Tag','YAxisChoice');t.verifyEqual(string(y.Value),"none");
            ax=findall(a.view.UIFigure,'Tag','ParameterMap');t.verifyEqual(ax.View,[0,90]);
        end
        function overlayNoneAuto2D(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            a.view.setOverlaySelection(1,true);a.view.setAxes("soc_pct","none","Rs_Ohm");a.view.setOverlayMode("3D ECM 파라미터");
            ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyEqual(ax.View,[0,90]);t.verifyNotEmpty(findall(ax,'Type','scatter'));
            a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyNotEqual(ax.View,[0,90]);
        end
    end
end

function waitUntil(predicate,limit)
started=tic;
while ~predicate()&&toc(started)<limit,pause(.1);drawnow;end
assert(predicate(),'Timed out waiting for session load');
end
