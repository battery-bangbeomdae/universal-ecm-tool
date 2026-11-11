classdef TestV81AxisAudit < matlab.unittest.TestCase
    properties
        Root
        Input
        Bundle
        Folder
    end
    methods(TestClassSetup)
        function fixture(t)
            t.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.Root);
            t.Folder=string(tempname);mkdir(t.Folder);t.addTeardown(@()rmdir(t.Folder,'s'));
            o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;
            t.Input=uecm.readInput(fullfile(t.Root,'examples','SYNTHETIC_eis_practice.csv'),o);t.Bundle=uecm.analyze(t.Input);
        end
    end
    methods(Test)
        function metadataCodesAreNotConditionAxes(t)
            b=t.Bundle;def=b.CustomAxes(1);def.Field="custom_temperature_basis";def.Column="temperature_basis";def.Label="온도 근거";def.Source="imported:test";
            b.CustomAxes(end+1)=def;b.Results.(def.Field)=ones(height(b.Results),1);text=repmat("Legacy condition reference / paper/source.pdf ",1,10);
            b.AxisCategories(end+1)=struct('Field',def.Field,'Values',join(text,""));
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));m.Bundle=b;
            [f,~]=v.availableAxisChoices("*");t.verifyFalse(ismember(def.Field,f));t.verifyTrue(ismember("soc_pct",f));
            A=uecm.axisInventory(b);a=A(A.field==def.Field,:);t.verifyFalse(a.allowed_condition);t.verifyGreaterThan(a.result_known_rows,0);
            t.verifyEqual(v.Bundle.Results,b.Results);t.verifyEqual(v.Bundle.AxisCategories,b.AxisCategories);
        end
        function explicitNumericAxisIsKept(t)
            M=table(t.Bundle.Results.fit_id,ones(height(t.Bundle.Results),1),'VariableNames',{'fit_id','source_pressure'});
            b=uecm.addCustomAxis(t.Bundle,M,"source_pressure","실험자가 선택한 압력","kPa","fit_id","user.csv");
            A=uecm.axisInventory(b);a=A(A.field=="custom_source_pressure",:);t.verifyTrue(a.selectable);t.verifyTrue(contains(a.reason,'직접'));
        end
        function categoryTicksUseOnlyVisibleValuesAndStayShort(t)
            f=uifigure('Visible','off');t.addTeardown(@()delete(f));ax=uiaxes(f);
            labels="category_"+(1:40)'+repmat("_long_category_name",40,1);b=struct('AxisCategories',struct('Field',"custom_protocol",'Values',labels));
            scatter3(ax,[3,3],[25,25],[.01,.02]);uecm.applyCategoryTicks(ax,b,"custom_protocol","temperature_C","Rs_Ohm");
            t.verifyEqual(ax.XTick,3);t.verifyLessThanOrEqual(strlength(string(ax.XTickLabel)),25);t.verifyEqual(string(ax.TickLabelInterpreter),"none");
        end
        function rawExtraColumnIsPreserved(t)
            T=t.Input.Data;T.pressure_kPa=123*ones(height(T),1);file=fullfile(t.Folder,'raw_extra.csv');writetable(T,file);
            o=t.Input.Settings;o.ImportMode="raw";i=uecm.readInput(file,o);p=uecm.prepare(i);
            t.verifyTrue(ismember('pressure_kPa',i.Data.Properties.VariableNames));t.verifyEqual(i.Data.pressure_kPa,T.pressure_kPa);
            t.verifyTrue(ismember('custom_pressure_kPa',p.Data.Properties.VariableNames));
        end
        function appendDistinguishesPendingFromFittedVariables(t)
            first=fullfile(t.Folder,'append_a.csv');second=fullfile(t.Folder,'append_b.csv');T=t.Input.Data;writetable(T,first);T.pressure_kPa=50*ones(height(T),1);writetable(T,second);
            o=t.Input.Settings;o.ImportMode="template";a=uecm.readInput(first,o);ba=uecm.analyze(a);
            loaded=uecm.workspaceLoad(second,o,"",a,ba,"append",@(~)[]);
            A=uecm.axisInventory(loaded.Bundle);q=A(A.field=="custom_pressure_kPa",:);
            t.verifyEqual(height(q),1);t.verifyGreaterThan(q.input_known_rows,0);t.verifyEqual(q.result_known_rows,0);t.verifyFalse(q.selectable);
            fitted=uecm.workspaceFit(loaded.Input,loaded.Bundle,true,@(~)[]);A=uecm.axisInventory(fitted);q=A(A.field=="custom_pressure_kPa",:);
            t.verifyTrue(q.selectable);t.verifyGreaterThan(q.result_known_rows,0);
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));m.Bundle=fitted;
            [fields,~]=v.availableAxisChoices(second);t.verifyFalse(ismember("custom_pressure_kPa",fields));
            M=fitted.Results(:,{'fit_id'});M.pressure_kPa=50*ones(height(M),1);v.importSelectedAxes(M,"pressure_kPa","fit_id","user.csv");
            [fields,~]=v.availableAxisChoices(second);t.verifyTrue(ismember("custom_selected_pressure_kPa",fields));
            [fields,~]=v.availableAxisChoices(first);t.verifyFalse(ismember("custom_pressure_kPa",fields));
        end
        function samePathNewColumnReusesFitsAndUpdatesConditions(t)
            file=fullfile(t.Folder,'same_path.csv');T=t.Input.Data;writetable(T,file);o=t.Input.Settings;o.ImportMode="template";
            i=uecm.readInput(file,o);b=uecm.analyze(i);T.pressure_kPa=77*ones(height(T),1);writetable(T,file);
            loaded=uecm.workspaceLoad(file,o,"",i,b,"append",@(~)[]);
            t.verifyEqual(loaded.Bundle.Results.Rs_Ohm,b.Results.Rs_Ohm);
            t.verifyEqual(loaded.Bundle.Results.custom_pressure_kPa,77*ones(height(b.Results),1));
            A=uecm.axisInventory(loaded.Bundle);t.verifyTrue(A.selectable(A.field=="custom_pressure_kPa"));
        end
        function obsoleteAuditButtonIsRemoved(t)
            a=launch_universal_ecm();t.addTeardown(@()delete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            t.verifyEmpty(findall(a.view.UIFigure,'Tag','AxisVariableAudit'));
            t.verifyEqual(string(findall(a.view.UIFigure,'Tag','CustomAxisImport').Text),"변수 추가하기");
        end
    end
end
