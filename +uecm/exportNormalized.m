function folder=exportNormalized(input,parent)
%EXPORTNORMALIZED Export prepared signals and linked conditions before fitting.
arguments
    input (1,1) struct
    parent (1,1) string
end
parent=uecm.validateOutputParent(parent);
p=uecm.prepare(input);parts={p};if isfield(p,'FilePrepared'),parts=p.FilePrepared;end
if all(cellfun(@(q)q.Blocked,parts))
    error('uecm:ExportBlocked','단위·신호·식별자 등 필수 진단을 먼저 해결하세요. 조건 공란은 내보내기를 막지 않습니다.');
end
stamp=string(datetime('now','Format','yyyyMMdd_HHmmss_SSS','TimeZone','Asia/Seoul'));
folder=fullfile(parent,"ECM_standard_"+stamp);n=0;
while isfolder(folder),n=n+1;folder=fullfile(parent,"ECM_standard_"+stamp+"_"+n);end
mkdir(folder);writelines("Incomplete export: do not use until this marker is removed.",fullfile(folder,'_INCOMPLETE.txt'));
writetable(p.AxisCoverage,fullfile(folder,'axis_condition_coverage.csv'),'Encoding','UTF-8');
manifest={};catalog={};filelog={};
internal=["soc","soh","temperature","cycle","initial_capacity","current_capacity","calendar"];
external=["soc_pct","soh_pct","temperature_C","cycle_number","initial_capacity_Ah","current_capacity_Ah","calendar_days"];
desc=["cell_model","cathode_family","cathode_composition","cell_format"];
for part=1:numel(parts)
    q=parts{part};item=q.Input;D=q.Data;
    record=struct('input_file',string(item.File),'measurement_type',q.Type,'rows',height(D),'status',"exported",'reason',"");
    if q.Blocked
        record.status="blocked";record.reason=join(q.Requests.Reason(q.Requests.Blocking),"; ");filelog{end+1,1}=record;continue
    end
    experiment="EX"+compose('%04d',part)+"_"+q.Type;
    rel=fullfile('experiments',experiment);dest=fullfile(folder,rel);mkdir(dest);
    S=table(D.source,D.cell,D.test,strings(height(D),1),strings(height(D),1),zeros(height(D),1), ...
        'VariableNames',{'source_id','cell_id','test_id','spectrum_id','measurement_id','point_index'});
    if q.Type=="EIS"
        S.frequency_hz=D.frequency;S.z_real_ohm=D.real;S.z_imag_ohm=D.imag;
    else
        S.time_s=D.time;S.current_A=-D.current;S.voltage_V=D.voltage;
    end
    % Keep every normalized row and varying/missing conditions; never flatten them.
    for j=1:numel(internal)
        S.(external(j))=D.(internal(j));
        S.(internal(j)+"_basis")=D.(internal(j)+"_source");
    end
    for name=desc,S.(name)=D.(name);end
    S.synthetic=repmat(logical(item.Synthetic),height(D),1);
    S.input_data_row=(1:height(D))';
    for name=["raw_source_row","source_row","source_line","source_file","raw_source_file","source_sheet"]
        if ismember(name,string(item.Data.Properties.VariableNames)),S.(name)=item.Data.(name);end
    end
    groups=findgroups(D.source,D.cell,D.test,D.spectrum);
    groupRows=accumarray(groups,(1:height(D))',[],@(idx){sort(idx)});
    C={};P={};
    for k=1:numel(groupRows)
        idx=groupRows{k};first=idx(1);id=experiment+"_M"+compose('%06d',k);
        S.spectrum_id(idx)=id;S.measurement_id(idx)=id;S.point_index(idx)=(1:numel(idx))';
        c=struct('source_id',D.source(first),'cell_id',D.cell(first),'test_id',D.test(first), ...
            'spectrum_id',id,'measurement_id',id,'measurement_type',q.Type);
        varying=strings(0,1);
        for j=1:numel(internal)
            values=D.(internal(j))(idx);finite=values(isfinite(values));c.(external(j))=NaN;
            if numel(finite)==numel(values)&&numel(unique(finite))==1,c.(external(j))=finite(1);
            elseif ~isempty(finite),varying(end+1)=external(j);end %#ok<AGROW>
            c.(internal(j)+"_basis")=join(unique(D.(internal(j)+"_source")(idx),'stable'),"; ");
        end
        for name=desc
            values=unique(D.(name)(idx));c.(name)="";
            if numel(values)==1,c.(name)=values;else,varying(end+1)=name;end %#ok<AGROW>
        end
        c.original_spectrum_id=D.spectrum(first);c.varies_within_measurement=join(varying,";");
        c.condition_reference="normalized import; see provenance.csv and normalization.json";
        C{end+1,1}=c; %#ok<AGROW>
        physical=item.File;sheet="";
        if isfield(item,'SourceFile'),physical=string(item.SourceFile);end
        if isfield(item,'SourceSheet'),sheet=string(item.SourceSheet);end
        P{end+1,1}=struct('source_id',c.source_id,'cell_id',c.cell_id,'test_id',c.test_id,'spectrum_id',id, ...
            'measurement_id',id,'original_spectrum_id',c.original_spectrum_id,'source_file',physical, ...
            'source_sha256',"",'output_first_row_1based',first,'output_last_row_1based',idx(end), ...
            'source_first_row_1based',NaN,'source_last_row_1based',NaN,'source_columns',join(string(item.Data.Properties.VariableNames),";"), ...
            'conversion_rule_id',"normalized_units_and_signs_see_normalization_json",'exclusion_reason',"", ...
            'source_sheet_or_variable',sheet,'input_id',item.File,'input_first_data_row',first,'input_last_data_row',idx(end), ...
            'input_rows_contiguous',all(diff(idx)==1),'point_count',numel(idx), ...
            'row_mapping',"signals.csv input_data_row; raw_source_row/source_row/source_line when supplied"); %#ok<AGROW>
    end
    conditions=struct2table(vertcat(C{:}));provenance=struct2table(vertcat(P{:}));
    writeCSV(S,fullfile(dest,'signals.csv'),'Encoding','UTF-8');
    writeCSV(conditions,fullfile(dest,'measurements.csv'),'Encoding','UTF-8');
    writeCSV(provenance,fullfile(dest,'provenance.csv'),'Encoding','UTF-8');
    cells=unique(S(:,["source_id","cell_id",desc]),'rows','stable');catalog{end+1,1}=cells; %#ok<AGROW>
    info=struct('input_file',item.File,'synthetic',item.Synthetic,'type',q.Type,'settings',item.Settings, ...
        'metadata_file',item.MetadataFile,'mapping',item.Mapping,'conversions',q.Conversions,'notes',q.Notes, ...
        'signal_rows',height(S),'measurement_groups',height(conditions),'fit_performed',false, ...
        'export_current_sign',"charge_positive",'export_imaginary_sign',"signed_imaginary", ...
        'grouping',"original source/cell/test/spectrum; HPPC may include multiple pulses per measurement");
    writelines(string(jsonencode(info,'PrettyPrint',true)),fullfile(dest,'normalization.json'),'Encoding','UTF-8');
    writeCSV(q.Requests,fullfile(dest,'diagnostics.csv'),'Encoding','UTF-8');
    manifest{end+1,1}=struct('schema_version',"1.0",'experiment_id',experiment,'measurement_type',q.Type, ...
        'signal_file',string(fullfile(rel,'signals.csv')),'conditions_file',string(fullfile(rel,'measurements.csv')), ...
        'cells_file',"cells.csv",'provenance_file',string(fullfile(rel,'provenance.csv')), ...
        'current_sign',"charge_positive",'synthetic',item.Synthetic,'status',"normalized_not_fitted"); %#ok<AGROW>
    filelog{end+1,1}=record; %#ok<AGROW>
end
writeCSV(struct2table(vertcat(manifest{:})),fullfile(folder,'manifest.csv'),'Encoding','UTF-8');
cells=unique(vertcat(catalog{:}),'rows','stable');
cells.cell_model_id=cells.cell_model;cells.manufacturer=strings(height(cells),1);
cells.nominal_capacity_Ah=nan(height(cells),1);cells.information_source=strings(height(cells),1);
cells.information_basis=repmat("normalized input descriptors; see per-experiment normalization.json",height(cells),1);
writeCSV(cells,fullfile(folder,'cells.csv'),'Encoding','UTF-8');
writeCSV(struct2table(vertcat(filelog{:})),fullfile(folder,'export_log.csv'),'Encoding','UTF-8');
if isfield(input,'ImportLog'),writeCSV(input.ImportLog,fullfile(folder,'import_log.csv'),'Encoding','UTF-8');end
if isfield(input,'ConditionLabels'),writeCSV(input.ConditionLabels,fullfile(folder,'manual_condition_labels.csv'),'Encoding','UTF-8');end
writelines(["# 도구 표준 CSV 내보내기"; ...
    "피팅 전 표준화 데이터입니다. 원본은 변경하지 않았습니다. manifest.csv에서 EIS/HPPC와 입력 쌍을 확인하세요."; ...
    "실험별 signals.csv를 표준 입력으로 열고 같은 폴더의 measurements.csv를 조건표로 연결합니다. manifest 자동 연결은 아직 지원하지 않습니다."; ...
    "표준 단위 Hz/Ω/s/A/V, signed Im(Z), 충전 양수 전류입니다. HPPC를 다시 읽을 때 charge_positive를 선택하세요."; ...
    "SOC/SOH[%], 온도[°C], 사이클, 초기·현재 실측 용량[Ah]을 보존하며 결측은 비워 둡니다."; ...
    "한 측정 안에서 변하는 조건과 일부 결측은 signals.csv에 그대로 남기고 조건표 대표값은 비웁니다. 원래 시험/스펙트럼 단위를 유지하며 HPPC 펄스를 새로 잘라내지 않습니다."; ...
    "양수 Im도 보존합니다. 단위/부호 변환·연결·입력 정제 기록은 normalization.json을 확인하세요. 원시 데이터 재검증/피팅 품질 보증을 뜻하지 않습니다."; ...
    "provenance와 input_data_row는 입력 표의 행 대응이며 원시 물리 행 번호는 제공된 raw_source_row 등으로만 추적합니다. 원시 파일 해시를 새로 계산하지 않았습니다."; ...
    "export_log.csv에서 보류된 입력을 확인하세요. 가상 자료는 synthetic=true로 표시되며 실제 자료로 사용하지 마세요."], ...
    fullfile(folder,'README_ko.md'),'Encoding','UTF-8');
delete(fullfile(folder,'_INCOMPLETE.txt'));
end

function writeCSV(T,file,varargin)
% Use 17 significant digits instead of writetable's default numeric rounding.
U=T;
for name=string(T.Properties.VariableNames)
    v=T.(name);
    if isnumeric(v)
        text=compose("%.17g",v);text(~isfinite(v))="";U.(name)=text;
    end
end
writetable(U,file,varargin{:});
end
