classdef TestV81VariablePicker < matlab.uitest.TestCase
    properties
        Input
        Bundle
        Root
    end
    methods(TestClassSetup)
        function fixture(t)
            t.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.Root);
            o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;t.Input=uecm.readInput(fullfile(t.Root,'examples','SYNTHETIC_eis_practice.csv'),o);t.Bundle=uecm.analyze(t.Input);
        end
    end
    methods(Test)
        function defaultsHideAutoColumnsAndKeepData(t)
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));b=t.Bundle;
            def=b.CustomAxes(1);def.Field="custom_pressure";def.Column="pressure";def.Label="pressure";def.Source="imported:fixture";b.CustomAxes(end+1)=def;b.Results.custom_pressure=50*ones(height(b.Results),1);m.Bundle=b;
            [catalog,~]=v.axisChoices();t.verifyEqual(catalog,["soc_pct","soh_pct","temperature_C","cycle_number"]);
            [fields,~]=v.availableAxisChoices("*");t.verifyTrue(all(ismember(fields,catalog)));t.verifyEqual(v.Bundle.Results,b.Results);
        end
        function mainButtonsAndHeaderCheckboxesAddOnlyChosenColumn(t)
            a=launch_universal_ecm();t.addTeardown(@()safeDelete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            t.verifyEmpty(findall(a.view.UIFigure,'Tag','AxisVariableAudit'));button=findall(a.view.UIFigure,'Tag','CustomAxisImport');t.verifyEqual(string(button.Text),"변수 추가하기");
            M=table(t.Bundle.Results.fit_id,(1:height(t.Bundle.Results))',100*ones(height(t.Bundle.Results),1),'VariableNames',{'fit_id','pressure_kPa','unused'});
            a.view.showVariablePicker(M,"SYNTHETIC_picker.csv");win=findall(groot,'Tag','VariableImportWindow');t.verifyEqual(findall(win,'Tag','VariableCSVPreview').Data,M);
            checks=findall(win,'Tag','VariableColumnChoice');choice=checks(arrayfun(@(h)string(h.UserData)=="pressure_kPa",checks));t.press(choice);
            exportapp(win,fullfile(t.Root,'merge_provenance','v8_1_variable_picker','SYNTHETIC_csv_column_checkboxes.png'));
            t.press(findall(win,'Tag','ApplySelectedVariables'));
            t.verifyFalse(isvalid(win));[fields,~]=a.viewModel.availableAxisChoices("*");t.verifyTrue(ismember("custom_pressure_kPa",fields));t.verifyFalse(ismember("custom_unused",fields));
            t.verifyEqual(a.viewModel.Bundle.Results.custom_pressure_kPa,M.pressure_kPa);t.verifyEqual(a.viewModel.Bundle.Results.Rs_Ohm,t.Bundle.Results.Rs_Ohm);
        end
        function sameAutoColumnGetsSeparateUserAxis(t)
            b=t.Bundle;def=b.CustomAxes(1);def.Field="custom_pressure";def.Column="pressure";def.Source="imported:fixture";def.Label="pressure";b.CustomAxes(end+1)=def;b.Results.custom_pressure=77*ones(height(b.Results),1);
            M=table(b.Results.fit_id,88*ones(height(b.Results),1),'VariableNames',{'fit_id','pressure'});
            result=uecm.addSelectedAxes(b,M,"pressure","fit_id","user.csv");t.verifyEqual(result.Results.custom_pressure,b.Results.custom_pressure);t.verifyEqual(result.Results.custom_selected_pressure,M.pressure);
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));m.Bundle=result;[fields,~]=v.availableAxisChoices("*");
            t.verifyTrue(ismember("custom_selected_pressure",fields));t.verifyFalse(ismember("custom_pressure",fields));
        end
        function repeatedRowsAndCategoryValuesLinkByIdentity(t)
            b=t.Bundle;ids=b.Results.fit_id;M=table([ids;ids],[repmat("A",numel(ids),1);repmat("A",numel(ids),1)],'VariableNames',{'fit_id','protocol'});
            result=uecm.addSelectedAxes(b,M,"protocol","fit_id","user.csv");t.verifyEqual(result.Results.custom_protocol,ones(height(b.Results),1));
            j=find(string({result.AxisCategories.Field})=="custom_protocol");t.verifyEqual(result.AxisCategories(j).Values,"A");
            reversed=flipud(table(ids,(1:numel(ids))','VariableNames',{'fit_id','dose'}));result=uecm.addSelectedAxes(b,reversed,"dose","fit_id","user.csv");t.verifyEqual(result.Results.custom_dose,(1:numel(ids))');
        end
        function conflictingRowsAndFailedBatchAreAtomic(t)
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));m.Bundle=t.Bundle;before=v.Bundle;
            ids=t.Bundle.Results.fit_id;M=table(ids,ones(numel(ids),1),nan(numel(ids),1),'VariableNames',{'fit_id','good','empty'});
            t.verifyError(@()v.importSelectedAxes(M,["good","empty"],"fit_id","test.csv"),'uecm:CustomAxis');t.verifyEqual(v.Bundle,before);
            M=M(1:2,{'fit_id','good'});M.fit_id(:)=ids(1);M.good=[1;2];
            t.verifyError(@()v.importSelectedAxes(M,"good","fit_id","test.csv"),'uecm:CustomAxis');t.verifyEqual(v.Bundle,before);
        end
        function cancelAndStalePickerDoNotChangeResults(t)
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));m.Bundle=t.Bundle;
            M=table(t.Bundle.Results.fit_id,ones(height(t.Bundle.Results),1),'VariableNames',{'fit_id','dose'});
            picker=uecm.Views.VariableImportView(v,M,"test.csv");t.addTeardown(@()safeDelete(picker));picker.setSelectedColumns("dose");v.Revision=v.Revision+1;picker.apply();
            t.verifyTrue(isvalid(picker));note=findall(picker.UIFigure,'Tag','VariableImportStatus');t.verifyTrue(contains(string(note.Text),"결과가 변경"));t.verifyEqual(v.Bundle,t.Bundle);
            t.press(findall(picker.UIFigure,'Tag','CancelSelectedVariables'));t.verifyFalse(isvalid(picker));t.verifyEqual(v.Bundle,t.Bundle);
        end
        function fullCSVValidationIncludesRowsPastPreview(t)
            ids=repmat(t.Bundle.Results.fit_id(1),201,1);dose=ones(201,1);dose(201)=2;M=table(ids,dose,'VariableNames',{'fit_id','dose'});
            t.verifyError(@()uecm.addSelectedAxes(t.Bundle,M,"dose","fit_id","user.csv"),'uecm:CustomAxis');
        end
        function CSVReaderPreservesIdentifierLeadingZeros(t)
            file=string(tempname)+".csv";t.addTeardown(@()delete(file));writelines(["cell_id,pressure_kPa";"001,20";"002,30"],file);
            result=uecm.Models.SessionModel.readCustomConditions(file);t.verifyEqual(result.Table.cell_id,["001";"002"]);t.verifyEqual(result.ColumnInfo.known_rows(2),2);
        end
        function mainCloseAlsoClosesPicker(t)
            a=launch_universal_ecm();t.addTeardown(@()safeDelete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            M=table(t.Bundle.Results.fit_id,ones(height(t.Bundle.Results),1),'VariableNames',{'fit_id','dose'});a.view.showVariablePicker(M,"test.csv");win=findall(groot,'Tag','VariableImportWindow');
            close(a.view.UIFigure);drawnow;t.verifyFalse(isvalid(win));t.verifyFalse(isvalid(a.view));
        end
    end
end
function safeDelete(obj)
if isvalid(obj),delete(obj);end
end
