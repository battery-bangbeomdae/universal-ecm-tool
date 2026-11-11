function input=readInputs(files,settings,metadataFile)
%READINPUTS Combine files and workbook sheets, preserving per-input identity.
arguments
    files (:,1) string
    settings (1,1) struct = uecm.defaults()
    metadataFile (1,1) string = ""
end
parts={};logs={};
if numel(unique(lower(files)))~=numel(files)
    error('uecm:DuplicateFiles','같은 파일이 중복 선택되었습니다.');
end
for k=1:numel(files)
    opts=settings;
    if isfield(settings,'BatchSheets')&&numel(settings.BatchSheets)==numel(files),opts.Sheet=settings.BatchSheets(k);end
    try
        [items,log]=uecm.readMeasurementFile(files(k),opts,metadataFile);
    catch ex
        status="unreadable";if string(ex.identifier)=="uecm:InputType",status="type_mismatch";end
        logs{end+1,1}=table(files(k),"",status,0,"",string(ex.message), ...
            'VariableNames',{'file','sheet','status','rows','profile','message'});
        continue
    end
    for j=1:numel(items)
        item=items{j};
        if ~isempty(parts)&&parts{1}.Synthetic~=item.Synthetic
            error('uecm:BatchSynthetic','실제 자료와 가상 자료는 따로 선택하세요.');
        end
        if any(ismember(["uecm_input_file","uecm_input_row"],string(item.Data.Properties.VariableNames)))
            error('uecm:BatchReserved','uecm_input_file / uecm_input_row는 다중 입력의 출처 기록용 예약 열입니다.');
        end
        parts{end+1,1}=item; %#ok<AGROW>
    end
    logs{end+1,1}=log; %#ok<AGROW>
end
log=vertcat(logs{:});
if isempty(parts)
    messages=log.file+" · "+log.sheet+" · "+log.message;
    error('uecm:Inputs','읽을 수 있는 측정 입력이 없습니다.\n%s',join(messages(1:min(12,end)),newline));
end
input=uecm.combineInputs(parts,settings);input.ImportLog=log;
end
