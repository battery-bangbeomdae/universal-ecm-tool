function A=axisInventory(bundle,file,continueFcn)
%AXISINVENTORY Distinguish source columns, metadata codes and plottable conditions.
arguments
    bundle struct
    file string = "*"
    continueFcn = []
end
fields=["soc_pct","temperature_C","soh_pct","cycle_number","calendar_days","initial_capacity_Ah","current_capacity_Ah"];
labels=["SOC [%]","온도 [°C]","SOH [%]","사이클 수","열화 경과일 [day]","초기 실측 용량 [Ah]","현재 실측 용량 [Ah]"];
normalized=["soc","temperature","soh","cycle","calendar","initial_capacity","current_capacity"];
columns=fields;manual=false(size(fields));builtin=true(size(fields));
if isfield(bundle,'CustomAxes')
    for def=bundle.CustomAxes
        if ismember(string(def.Field),fields),continue,end
        fields(end+1)=def.Field;columns(end+1)=def.Column;normalized(end+1)=def.Field;
        labels(end+1)=def.Label;if strlength(def.Unit)>0,labels(end)=labels(end)+" ["+def.Unit+"]";end
        manual(end+1)=~startsWith(string(def.Source),"imported:");builtin(end+1)=false;
    end
end
R=table();if isfield(bundle,'Results'),R=bundle.Results;end
if file~="*"&&strlength(file)>0&&ismember('source_file',R.Properties.VariableNames),R=R(string(R.source_file)==file,:);end
parts={};if isfield(bundle,'Prepared')
    parts={bundle.Prepared};if isfield(bundle.Prepared,'FilePrepared'),parts=bundle.Prepared.FilePrepared;end
end
rows=cell(numel(fields),1);
for k=1:numel(fields)
    if ~isempty(continueFcn)&&~continueFcn(),A=table();return,end
    field=fields(k);resultKnown=0;values=[];inputKnown=0;
    if ismember(field,string(R.Properties.VariableNames))&&isnumeric(R.(field))
        values=R.(field);values=values(isfinite(values));resultKnown=numel(values);
    end
    sourceNames=strings(0,1);
    for q=1:numel(parts)
        p=parts{q};if file~="*"&&strlength(file)>0&&string(p.Input.File)~=file,continue,end
        if builtin(k)
            source="";
            if isfield(p.Input,'Mapping')&&isfield(p.Input.Mapping,normalized(k)),source=string(p.Input.Mapping.(normalized(k)));end
            if strlength(source)>0&&isfield(p.Input,'RawReport')
                map=p.Input.RawReport.Mapping;hit=find(string(map.role)==source,1);
                if ~isempty(hit),source=string(map.source_column(hit));end
            end
            if strlength(source)==0&&isfield(p.Input,'Metadata')&&~isempty(p.Input.Metadata)
                mapping=uecm.inferMapping(p.Input.Metadata.Properties.VariableNames);
                if isfield(mapping,normalized(k)),source=string(mapping.(normalized(k)));end
            end
            if strlength(source)>0,sourceNames(end+1,1)=source;end
        end
        if ismember(normalized(k),string(p.Data.Properties.VariableNames))
            v=p.Data.(normalized(k));if isnumeric(v),inputKnown=inputKnown+nnz(isfinite(v));end
        end
    end
    column=columns(k);if ~isempty(sourceNames),column=join(unique(sourceNames,'stable')," | ");end
    category=strings(0,1);
    if isfield(bundle,'AxisCategories')
        j=find(string({bundle.AxisCategories.Field})==field,1);
        if ~isempty(j),category=string(bundle.AxisCategories(j).Values(:));end
    end
    allowed=true;reason="수치 열: 조건 후보 (원문 확인)";kind="숫자";
    if ~isempty(category),kind="범주 (표시용 코드)";reason="짧은 범주 조건";end
    if manual(k),reason="사용자가 직접 등록한 조건";
    elseif ~builtin(k)
        name=lower(regexprep(columns(k),'[^a-zA-Z0-9가-힣]+','_'));
        meta='(^|_)(basis|notes?|comments?|remarks?|reason|provenance|evidence|curation|processing|pipeline|schema|synthetic|version|validation|verified|status|hash|uuid|uid|reference|review|prior|unclipped|uncertainty|samples)(_|$)|(^|_)(id|idx|index|row)(_|$)|(^|_)(file|filename|path)(_|$)|(^|_)sources?$|source_(text|file|id|reference)|condition_reference|measurement_type|^domain$|_kind$|^paper_excluded_';
        if ~isempty(regexp(char(name),meta,'once'))
            allowed=false;reason="출처·설명·식별/처리 메타데이터";
        elseif ~isempty(category)&&(any(strlength(category)>64)||numel(category)>20)
            allowed=false;reason="긴 문장/고유값이 많은 범주: 자동 축 제외";
        end
    end
    selectable=allowed&&resultKnown>0;
    if ~allowed,status="축 제외 (정보 보존)";
    elseif selectable,status="선택 가능";
    elseif inputKnown>0&&height(R)==0,status="입력 연결됨 · 피팅 대기";
    elseif inputKnown>0,status="입력 연결됨 · 결과 미연결/피팅 대기";
    else,status="현재 범위에서 미연결";end
    preview="";
    for j=1:min(3,numel(category))
        v=replace(category(j),newline," ");if strlength(v)>24,v=extractBefore(v,24)+"…";end
        if j>1,preview=preview+" | ";end
        preview=preview+v;
    end
    rows{k}=struct('field',field,'source_column',column,'label',labels(k),'kind',kind,'input_known_rows',inputKnown,'result_known_rows',resultKnown,'distinct_result_values',numel(unique(values)),'allowed_condition',allowed,'selectable',selectable,'status',status,'reason',reason,'category_preview',preview);
end
A=struct2table(vertcat(rows{:}));
end
