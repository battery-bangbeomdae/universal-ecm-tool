function folder = exportBundle(bundle,parent,viewSettings)
%EXPORTBUNDLE Write a NEW unique output directory, never overwrite source data.
arguments
    bundle (1,1) struct
    parent (1,1) string
    viewSettings (1,1) struct = struct()
end
parent=uecm.validateOutputParent(parent);
sizeInfo=whos('bundle');if sizeInfo.bytes>1.5e9,error('uecm:SessionSize','현재 세션 저장 범위(1.5 GB)를 넘습니다. 입력을 셀/시험 단위로 나누어 주세요.');end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS','TimeZone','Asia/Seoul'));
folder=fullfile(parent,"UniversalECM_"+string(stamp));counter=0;
while isfolder(folder),counter=counter+1;folder=fullfile(parent,"UniversalECM_"+string(stamp)+"_"+counter);end
mkdir(folder);
try
    if ~isempty(bundle.Results),writetable(bundle.Results,fullfile(folder,'estimated_parameters.csv'),'Encoding','UTF-8');end
    if isfield(bundle,'CustomAxes')&&~isempty(bundle.CustomAxes)
        A=bundle.CustomAxes;
        D=table(string({A.Field})',string({A.Label})',string({A.Unit})',string({A.Source})',string({A.Column})',strings(numel(A),1),[A.LinkedCount]',[A.MissingCount]', ...
            'VariableNames',{'Field','Label','Unit','Source','Column','Keys','LinkedCount','MissingCount'});
        for k=1:numel(A),D.Keys(k)=join(A(k).Keys," + ");end
        writetable(D,fullfile(folder,'custom_axis_definitions.csv'),'Encoding','UTF-8');
    end
    if isfield(bundle,'AxisCategories'),writelines(jsonencode(bundle.AxisCategories,'PrettyPrint',true),fullfile(folder,'axis_categories.json'));end
    writetable(uecm.conditionCoverage(bundle.Prepared),fullfile(folder,'axis_condition_coverage.csv'),'Encoding','UTF-8');
    input=bundle.Prepared.Input;
    if isfield(input,'ConditionLabels'),writetable(input.ConditionLabels,fullfile(folder,'measurement_condition_labels.csv'),'Encoding','UTF-8');end
    if isfield(input,'ImportLog')
        writetable(input.ImportLog,fullfile(folder,'folder_import_log.csv'),'Encoding','UTF-8');
    end
    parts={input};
    if isfield(input,'OriginalInputs'),parts=input.OriginalInputs;end
    mappings={};reports=strings(0,1);
    ids=strings(numel(parts),1);sources=ids;sheets=ids;
    for j=1:numel(parts)
        item=parts{j};ids(j)=item.File;sources(j)=item.File;
        if isfield(item,'SourceFile'),sources(j)=item.SourceFile;end
        if isfield(item,'SourceSheet'),sheets(j)=item.SourceSheet;end
    end
    writetable(table(ids,sources,sheets,'VariableNames',{'input_id','source_file','source_sheet'}), ...
        fullfile(folder,'input_file_catalog.csv'),'Encoding','UTF-8');
    for j=1:numel(parts)
        item=parts{j};
        if isfield(item,'RawReport')
            rr=item.RawReport;mapping=rr.Mapping;mapping.source_file=repmat(item.File,height(mapping),1);
            mappings{end+1}=mapping; %#ok<AGROW>
            reports=[reports;item.File;rr.Hints(:);rr.Requests(:)]; %#ok<AGROW>
        end
    end
    if ~isempty(mappings),writetable(vertcat(mappings{:}),fullfile(folder,'raw_column_mapping.csv'),'Encoding','UTF-8');end
    if ~isempty(reports),writelines(reports,fullfile(folder,'raw_import_report.txt'));end
    if isfield(viewSettings,'OverlayFiles')
        paths=string(viewSettings.OverlayFiles(:));
        writetable(table(paths,'VariableNames',{'source_file'}),fullfile(folder,'selected_files.csv'),'Encoding','UTF-8');
    end
    if isfield(viewSettings,'OverlayIndices')&&~isempty(bundle.Results)
        chosen=viewSettings.OverlayIndices;
        chosen=chosen(chosen>=1&chosen<=height(bundle.Results));
        writetable(bundle.Results(chosen,:),fullfile(folder,'selected_experiments.csv'),'Encoding','UTF-8');
    end
    if isfield(bundle,'Fits')&&~isempty(bundle.Fits)
        files=unique(string(cellfun(@(f)f.SourceFile,bundle.Fits,'UniformOutput',false)),'stable');
        summaries={};errors={};
        for j=1:numel(files)
            [S,total]=uecm.fileErrorSummary(bundle,files(j));S.source_file=repmat(files(j),height(S),1);errors{end+1}=S;
            summaries{end+1}=struct('source_file',files(j),'recommended_pooled_rmse',total.RMSE, ...
                'error_unit',total.ErrorUnit,'n_data',total.NData,'n_fit_points',total.NPoints);
        end
        writetable(struct2table(vertcat(summaries{:})),fullfile(folder,'file_error_summary.csv'),'Encoding','UTF-8');
        writetable(vertcat(errors{:}),fullfile(folder,'model_error_by_dataset.csv'),'Encoding','UTF-8');
        n=numel(bundle.Fits);
        if isfield(viewSettings,'OverlayFiles')&&isfield(viewSettings,'OverlayMeasuredEnabled')&&numel(viewSettings.OverlayMeasuredEnabled)==n&& ...
                isfield(viewSettings,'OverlayDataEnabled')&&numel(viewSettings.OverlayDataEnabled)==n&& ...
                isfield(viewSettings,'OverlayModelSelection')&&isequal(size(viewSettings.OverlayModelSelection),[n,3])
            paths=string(cellfun(@(f)f.SourceFile,bundle.Fits,'UniformOutput',false));
            enabled=logical(viewSettings.OverlayDataEnabled(:));measured=logical(viewSettings.OverlayMeasuredEnabled(:));
            M=logical(viewSettings.OverlayModelSelection);
            fileSelected=ismember(paths,string(viewSettings.OverlayFiles));
            selection=table(paths,bundle.Results.fit_id,fileSelected,enabled,measured,M(:,1),M(:,2),M(:,3), ...
                'VariableNames',{'source_file','fit_id','file_checked','data_checked','show_measured','show_1rc','show_2rc','show_zarcl'});
            writetable(selection,fullfile(folder,'plot_selection.csv'),'Encoding','UTF-8');
        end
    end
    writetable(bundle.Prepared.Requests,fullfile(folder,'additional_data_requests.csv'),'Encoding','UTF-8');
    % Researcher aids (never block the export): processing record for the Methods section, and where to measure next
    try,uecm.methodsSummary(bundle,fullfile(folder,'methods_summary_ko.md'));catch aex,warning('uecm:Aid','처리 기록을 쓰지 못했습니다: %s',aex.message);end
    try
        [nextT,skipT]=uecm.suggestNextMeasurements(bundle);
        if ~isempty(nextT),writetable(nextT,fullfile(folder,'next_measurement_suggestions.csv'),'Encoding','UTF-8');end
        if ~isempty(skipT),writetable(skipT,fullfile(folder,'skip_candidates_next_campaign.csv'),'Encoding','UTF-8');end
    catch aex,warning('uecm:Aid','다음 측정 제안을 만들지 못했습니다: %s',aex.message);end
    writelines(bundle.Prepared.Notes,fullfile(folder,'notes.txt'),'Encoding','UTF-8');
    save(fullfile(folder,'session.mat'),'bundle','viewSettings','-v7');
    info=struct('version',bundle.Version,'created',bundle.Timestamp,'input_file',bundle.Prepared.Input.File, ...
        'metadata_file',bundle.Prepared.Input.MetadataFile,'synthetic',bundle.Prepared.Input.Synthetic, ...
        'validation',"training_fit_only; independent validation not performed",'settings',bundle.Prepared.Input.Settings, ...
        'mapping',bundle.Prepared.Input.Mapping,'unit_conversions',bundle.Prepared.Conversions,'view',viewSettings);
    if isfield(bundle.Prepared.Input,'Files')
        info.input_files=bundle.Prepared.Input.Files;
        D=bundle.Prepared.Input.Data;
        manifest=table((1:height(D))',D.uecm_input_file,D.uecm_input_row, ...
            'VariableNames',{'input_data_row','source_file','source_data_row'});
        writetable(manifest,fullfile(folder,'input_file_rows.csv'),'Encoding','UTF-8');
    end
    writelines(string(jsonencode(info,'PrettyPrint',true)),fullfile(folder,'settings_and_provenance.json'),'Encoding','UTF-8');
    for k=1:numel(bundle.Fits)
        f=bundle.Fits{k};rows=f.SourceRows;
        if f.Domain=="EIS"
            P=table(rows,f.Frequency,real(f.Measured),imag(f.Measured),real(f.Predicted),imag(f.Predicted), ...
                'VariableNames',{'input_data_row','frequency_hz','measured_real_ohm','measured_imag_ohm','fitted_real_ohm','fitted_imag_ohm'});
        else
            P=table(rows,f.Time,f.Current,f.Measured,f.Predicted,f.Measured-f.Predicted, ...
                'VariableNames',{'input_data_row','time_since_pulse_s','current_discharge_positive_A','measured_voltage_V','fitted_voltage_V','residual_V'});
        end
        writetable(P,fullfile(folder,sprintf('fit_%04d_response.csv',k)),'Encoding','UTF-8');
    end
    allParams={};allScores={};
    for k=1:numel(bundle.Fits)
        selected=bundle.Fits{k};cc=uecm.candidatesOf(selected);
        if isfield(selected,'Preprocessing')
            R=selected.Preprocessing;writetable(R,fullfile(folder,sprintf('fit_%04d_eis_preprocessing.csv',k)),'Encoding','UTF-8');
        end
        if isfield(selected,'CandidateScores')
            S=selected.CandidateScores;S.fit_id=repmat(string(k),height(S),1);
            writetable(S,fullfile(folder,sprintf('fit_%04d_model_comparison.csv',k)),'Encoding','UTF-8');
            if ismember('Model',S.Properties.VariableNames),allScores{end+1}=S;end
        end
        for j=1:numel(cc)
            c=cc{j};prefix=sprintf('fit_%04d_%s',k,char(c.ModelName));
            if isfield(selected,'Identity'),r=uecm.candidateRow(selected.Identity,c);allParams{end+1}=r;end
            if ~isempty(c.History),writetable(c.History,fullfile(folder,string(prefix)+'_fitting_history.csv'),'Encoding','UTF-8');end
            if ~isempty(c.StartSummary),writetable(c.StartSummary,fullfile(folder,string(prefix)+'_initial_starts.csv'),'Encoding','UTF-8');end
            if c.Domain=="EIS"
                P=table(selected.SourceRows,c.Frequency,real(c.Measured),imag(c.Measured),real(c.Predicted),imag(c.Predicted), ...
                    'VariableNames',{'input_data_row','frequency_hz','measured_real_ohm','measured_imag_ohm','fitted_real_ohm','fitted_imag_ohm'});
            else
                P=table(selected.SourceRows,c.Time,c.Current,c.Measured,c.Predicted,c.Measured-c.Predicted, ...
                    'VariableNames',{'input_data_row','time_since_pulse_s','current_A','measured_voltage_V','fitted_voltage_V','residual_V'});
            end
            writetable(P,fullfile(folder,string(prefix)+'_response.csv'),'Encoding','UTF-8');
        end
    end
    if ~isempty(allParams),writetable(struct2table(vertcat(allParams{:})),fullfile(folder,'all_model_parameters.csv'),'Encoding','UTF-8');end
    if ~isempty(allScores),writetable(vertcat(allScores{:}),fullfile(folder,'all_model_comparison.csv'),'Encoding','UTF-8');end
    writelines(["이 폴더의 파라미터·모델 응답은 계산/추정 결과입니다."; ...
        "실측 원본과 섞지 마세요. session.mat에는 원본 입력 표와 설정·요청·결과가 들어 있습니다."; ...
        "학습 자료에 맞춘 결과이며 독립 시험/BMS 검증 완료를 뜻하지 않습니다."; ...
        "input_data_row는 읽은 입력 표의 1부터 시작하는 데이터 행 번호입니다. CSV 파일 줄 번호는 아닙니다."], ...
        fullfile(folder,'READ_ME_FIRST_ko.txt'),'Encoding','UTF-8');
catch ex
    writelines("저장 중 오류: "+string(ex.message),fullfile(folder,'INCOMPLETE_EXPORT.txt'));rethrow(ex);
end
end
