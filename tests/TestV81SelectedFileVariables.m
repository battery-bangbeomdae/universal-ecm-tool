classdef TestV81SelectedFileVariables < matlab.uitest.TestCase
    properties
        Root
        Folder
        Input
        Bundle
        HPPC
        Files
    end
    methods(TestClassSetup)
        function fixture(t)
            t.Root=fileparts(fileparts(mfilename('fullpath')));addpath(t.Root);t.Folder=string(tempname);mkdir(t.Folder);t.addTeardown(@()rmdir(t.Folder,'s'));
            o=uecm.defaults();o.EISModels="RC";o.EISAutoWarburg=false;parts=cell(1,2);t.Files=strings(2,1);
            for k=1:2
                T=readtable(fullfile(t.Root,'examples','SYNTHETIC_eis_practice.csv'),'TextType','string');T.pressure_kPa=100*k*ones(height(T),1);T=movevars(T,'pressure_kPa','After','source_id');
                file=fullfile(t.Folder,"SYNTHETIC_selected_"+k+".csv");writetable(T,file);t.Files(k)=file;i=uecm.readInput(file,o);
                ids=unique(string(T.spectrum_id),'stable');i.Metadata=table(ids,repmat("group_"+k,numel(ids),1),'VariableNames',{'spectrum_id','sidecar_group'});
                if k==2,i.Metadata.only_second_file=500*ones(height(i.Metadata),1);end
                parts{k}=i;
            end
            t.Input=uecm.combineInputs(parts,o);t.Bundle=uecm.analyze(t.Input);
            h=uecm.defaults();h.CurrentSign="charge_positive";parts=cell(1,2);
            for k=1:2
                T=readtable(fullfile(t.Root,'examples','REAL_D014_hppc_one_pulse.csv'),'TextType','string');T.TEST_ONLY_condition=10*k*ones(height(T),1);
                file=fullfile(t.Folder,"REAL_HPPC_fixture_"+k+".csv");writetable(T,file);parts{k}=uecm.readInput(file,h);
            end
            t.HPPC=uecm.analyze(uecm.combineInputs(parts,h));
        end
    end
    methods(Test)
        function extractsOnlySelectedFileAndPreservesFits(t)
            b=t.Bundle;r=uecm.selectedFileVariables(b,t.Files(2),7);
            t.verifyEqual(r.Revision,7);t.verifyEqual(r.Context.SelectedFile,t.Files(2));t.verifyEqual(r.Table.pressure_kPa,200*ones(height(r.Table),1));
            t.verifyEqual(r.Table.fit_id,b.Results.fit_id(string(b.Results.source_file)==t.Files(2)));
            t.verifyEqual(r.Context.Preview.pressure_kPa,200*ones(height(r.Context.Preview),1));t.verifyEqual(b,t.Bundle);
        end
        function decodesLinkedMetadataAndOmitsOtherFileColumns(t)
            a=uecm.selectedFileVariables(t.Bundle,t.Files(1));b=uecm.selectedFileVariables(t.Bundle,t.Files(2));
            t.verifyEqual(unique(b.Table.sidecar_group),"group_2");t.verifyEqual(unique(b.Context.Preview.sidecar_group),"group_2");
            t.verifyTrue(ismember('only_second_file',b.Table.Properties.VariableNames));t.verifyFalse(ismember('only_second_file',a.Table.Properties.VariableNames));
        end
        function changingSignalsAndExcludedPointAreNotAveraged(t)
            b=t.Bundle;p=b.Prepared.FilePrepared{2};p.Input.Data.pressure_kPa(1)=999;b.Prepared.FilePrepared{2}=p;
            i=find(string(b.Results.source_file)==t.Files(2),1);b.Fits{i}.SourceRows=b.Fits{i}.SourceRows(2:end);
            r=uecm.selectedFileVariables(b,t.Files(2));t.verifyTrue(isnan(r.Table.pressure_kPa(1)));
            j=r.ColumnInfo.column=="frequency_hz";t.verifyEqual(r.ColumnInfo.known_rows(j),0);t.verifyTrue(contains(r.ColumnInfo.reason(j),"값이 변하"));
        end
        function partialMissingValuesStayMissing(t)
            b=t.Bundle;p=b.Prepared.FilePrepared{2};p.Input.Data.pressure_kPa(1)=NaN;b.Prepared.FilePrepared{2}=p;
            r=uecm.selectedFileVariables(b,t.Files(2));t.verifyTrue(isnan(r.Table.pressure_kPa(1)));t.verifyTrue(all(r.Table.pressure_kPa(2:end)==200));
        end
        function HPPCUsesSelectedLocalRowsAfterGlobalOffset(t)
            file=string(t.HPPC.Prepared.FilePrepared{2}.Input.File);r=uecm.selectedFileVariables(t.HPPC,file);
            t.verifyEqual(r.Table.TEST_ONLY_condition,20*ones(height(r.Table),1));t.verifyTrue(all(isfinite(r.Table.TEST_ONLY_condition)));
        end
        function staleFileSelectionCannotApply(t)
            m=uecm.Models.SessionModel();v=uecm.ViewModels.MainViewModel(m);t.addTeardown(@()delete(v));m.Bundle=t.Bundle;v.SelectedFile=t.Files(1);
            r=uecm.selectedFileVariables(t.Bundle,t.Files(1));p=uecm.Views.VariableImportView(v,r.Table,r.File,r.ColumnInfo,r.Context);t.addTeardown(@()safeDelete(p));p.setSelectedColumns("pressure_kPa");v.SelectedFile=t.Files(2);p.apply();
            note=findall(p.UIFigure,'Tag','VariableImportStatus');t.verifyTrue(contains(string(note.Text),"선택 파일이 변경"));t.verifyEqual(v.Bundle,t.Bundle);
        end
        function buttonOpensLoadedFileWithoutChoosingAnotherFile(t)
            a=launch_universal_ecm();t.addTeardown(@()safeDelete(a.view));a.viewModel.acceptInput(t.Input);a.viewModel.acceptFit(t.Bundle);
            i=find(string(t.Bundle.Results.source_file)==t.Files(2),1);a.viewModel.selectFit(i);
            t.press(findall(a.view.UIFigure,'Tag','CustomAxisImport'));waitForPicker(a,120);
            win=findall(groot,'Tag','VariableImportWindow');checks=findall(win,'Tag','VariableColumnChoice');c=checks(arrayfun(@(h)string(h.UserData)=="pressure_kPa",checks));c.Value=true;
            preview=findall(win,'Tag','VariableCSVPreview');t.verifyTrue(all(preview.Data.pressure_kPa==200));
            key=findall(win,'Tag','VariableJoinKey');t.verifyEqual(string(key.Enable),"off");t.verifyTrue(key.Value);
            exportapp(win,fullfile(t.Root,'merge_provenance','v8_1_selected_file_variables','SYNTHETIC_selected_file_picker.png'));
            t.press(findall(win,'Tag','ApplySelectedVariables'));
            R=a.viewModel.Bundle.Results;selected=string(R.source_file)==t.Files(2);t.verifyTrue(all(R.custom_selected_pressure_kPa(selected)==200));t.verifyTrue(all(isnan(R.custom_selected_pressure_kPa(~selected))));
            t.verifyEqual(R.Rs_Ohm,t.Bundle.Results.Rs_Ohm);t.verifyFalse(isvalid(win));
        end
        function unknownOrUnfittedFileDoesNotFallBackToOtherFile(t)
            t.verifyError(@()uecm.selectedFileVariables(t.Bundle,"not_loaded.csv"),'uecm:SelectedVariables');
            b=t.Bundle;keep=string(b.Results.source_file)==t.Files(1);b.Results=b.Results(keep,:);b.Fits=b.Fits(keep);
            t.verifyError(@()uecm.selectedFileVariables(b,t.Files(2)),'uecm:SelectedVariables');
        end
    end
end
function safeDelete(o)
if isvalid(o),delete(o);end
end
function waitForPicker(a,limit)
started=tic;
while a.viewModel.Busy&&toc(started)<limit,pause(.05);drawnow;end
assert(~a.viewModel.Busy,'Variable extraction timed out');assert(~isempty(findall(groot,'Tag','VariableImportWindow')),'No selected-file picker opened');
end
