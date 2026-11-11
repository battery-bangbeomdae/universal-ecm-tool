classdef TestV81RightMapCleanup < matlab.unittest.TestCase
    properties
        Input
        Bundle
        Root
    end
    methods(TestClassSetup)
        function fixture(t)
            t.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.Root);
            o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
            t.Input=uecm.readInputs([string(fullfile(t.Root,'examples','SYNTHETIC_eis_practice.csv'));string(fullfile(t.Root,'examples','SYNTHETIC_2RC_eis_practice.csv'))],o,"");t.Bundle=uecm.analyze(t.Input);
        end
    end
    methods(Test)
        function metadataStaysCompactAndFullTextIsAvailable(t)
            b=t.Bundle;note=join(repmat("PROVENANCE_UNIQUE_MARKER source/path/paper.pdf",1,80),"; ");
            axis=b.CustomAxes(1);axis.Field="custom_curation_notes";axis.Label="검증 원문";axis.Unit="";axis.Source="imported:test";axis.Column="curation_notes";
            b.CustomAxes(end+1)=axis;b.Results.custom_curation_notes=ones(height(b.Results),1);
            b.AxisCategories(end+1)=struct('Field',axis.Field,'Values',note);
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(b);
            header=findall(a.view.UIFigure,'Tag','PrimaryConditions');t.verifyLessThan(strlength(string(header.Text)),220);
            t.verifyFalse(contains(string(header.Text),'PROVENANCE_UNIQUE_MARKER'));t.verifyEqual(header.Parent.Parent.RowHeight{1},68);
            a.view.showMeasurementDetails("primary");details=findall(groot,'Tag','FullMeasurementMetadata');
            actual=join(string(details.Value),newline);
            writelines(actual,fullfile(t.Root,'merge_provenance','v8_1_ui_cleanup','metadata_display_debug.txt'));
            writelines(uecm.customConditionText(a.viewModel.Bundle,a.viewModel.Bundle.Results(1,:)),fullfile(t.Root,'merge_provenance','v8_1_ui_cleanup','metadata_expected_debug.txt'));
            t.verifyTrue(contains(erase(actual,newline),note));t.verifyEqual(count(actual,"PROVENANCE_UNIQUE_MARKER"),80);t.verifyEqual(string(details.Editable),"off");
            t.verifyEqual(a.viewModel.Bundle.Results,b.Results);
            a.view.UIFigure.WindowState='normal';a.view.UIFigure.Position=[40,40,1600,900];drawnow;pause(.6);drawnow;
            out=fullfile(t.Root,'merge_provenance','v8_1_ui_cleanup');exportapp(a.view.UIFigure,fullfile(out,'SYNTHETIC_compact_summary.png'));
        end
        function scopeChangesOnlyRightMap(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");tabs=findall(a.view.UIFigure,'Tag','MainFittingResults');before=tabs.SelectedTab;
            a.view.setFilePlotMode("combined");drawnow;
            ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyNumElements(ax,1);t.verifyEqual(tabs.SelectedTab,before);
            t.verifyTrue(isAncestor(ax,findall(a.view.UIFigure,'Tag','MainMapPanel')));t.verifyNumElements(findall(ax,'Tag','OverlayParameterSeries'),2);
            a.view.UIFigure.WindowState='normal';a.view.UIFigure.Position=[40,40,1600,900];drawnow;pause(.6);drawnow;
            exportapp(a.view.UIFigure,fullfile(t.Root,'merge_provenance','v8_1_ui_cleanup','SYNTHETIC_right_combined.png'));
            a.view.setFilePlotMode("split");ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyNumElements(ax,2);t.verifyEqual(tabs.SelectedTab,before);
            grid=findall(a.view.UIFigure,'Tag','MainMapPlotGrid');t.verifyEqual(string(grid.Scrollable),"on");t.verifyEqual(grid.RowHeight,{420,420});
            drawnow;pause(.6);drawnow;exportapp(a.view.UIFigure,fullfile(t.Root,'merge_provenance','v8_1_ui_cleanup','SYNTHETIC_right_split.png'));
        end
        function rightMapFiltersAnd2DRemainCorrect(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            a.view.setAxes("soc_pct","none","Rs_Ohm");a.view.setFilePlotMode("combined");
            ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyEqual(ax.View,[0,90]);
            t.verifyEqual(numel(ax.UserData.FitIndices),height(t.Bundle.Results));
            a.view.setAxes("soc_pct","temperature_C","Rs_Ohm");ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyNotEqual(ax.View,[0,90]);
            a.view.setMapView("front");t.verifyEqual(ax.View,[0,0]);
            a.viewModel.setMapFilters(struct('cell_id',"NOT_A_CELL"));ax=findall(a.view.UIFigure,'Tag','MainParameterMap');t.verifyEmpty(ax.UserData.FitIndices);
            a.viewModel.setMapFilters(struct());t.verifyNotEmpty(findall(ax,'Tag','OverlayParameterSeries'));
            t.verifyEqual(a.viewModel.Bundle.Results,t.Bundle.Results);
        end
        function summaryNeverInventsMissingConditions(t)
            r=t.Bundle.Results(1,:);r.soc_pct=NaN;r.soh_pct=NaN;r.temperature_C=NaN;r.cycle_number=NaN;
            s=uecm.measurementBrief(r);t.verifyTrue(contains(s,'SOC 미연결'));t.verifyTrue(contains(s,'온도 미연결'));
            t.verifyEqual(numel(splitlines(s)),2);
        end
    end
end
function result=isAncestor(child,parent)
result=false;h=child.Parent;
while ~isempty(h)
    if h==parent,result=true;return,end
    h=h.Parent;
end
end
