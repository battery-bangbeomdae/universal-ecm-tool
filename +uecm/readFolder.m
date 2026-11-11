function input=readFolder(folder,settings,sendProgress)
%READFOLDER Recursively import independent measurement files and workbook sheets.
arguments
    folder (:,1) string
    settings (1,1) struct = uecm.defaults()
    sendProgress (1,1) function_handle = @(~)[]
end
settings=uecm.withDefaults(settings);
if isempty(folder)||any(~isfolder(folder)),error('uecm:Folder','실험 폴더를 찾을 수 없습니다.');end
% Canonical roots/files prevent duplicate reads for parent-child or repeated selections.
for j=1:numel(folder)
    [ok,info]=fileattrib(char(folder(j)));
    if ~ok,error('uecm:Folder','폴더 경로를 확인할 수 없습니다.');end
    folder(j)=string(info.Name);
end
folder=unique(folder,'stable');files=strings(0,1);
for j=1:numel(folder)
    sendProgress(struct('Message',"모든 하위 폴더 탐색 "+j+" / "+numel(folder)+" · "+folder(j)));
    entries=dir(fullfile(folder(j),'**','*'));entries=entries(~[entries.isdir]);
    for k=1:numel(entries)
        if contains(string(entries(k).folder),filesep+"ecm_result"+filesep+"matlab_uecm_cache_v1"),continue,end
        [ok,info]=fileattrib(fullfile(entries(k).folder,entries(k).name));
        if ok,files(end+1,1)=string(info.Name);end %#ok<AGROW>
    end
end
files=unique(files,'stable');
% Recognize manifest-paired signals before scanning ancillary condition/catalog files.
paired=strings(size(files));sidecars=strings(0,1);
for k=1:numel(files)
 [~,stem,extension]=fileparts(files(k));
 if strcmpi(stem,'signals')&&ismember(lower(extension),[".csv",".txt",".tsv"])
  [paired(k),extra]=uecm.manifestMetadataForFile(files(k));sidecars=union(sidecars,extra,'stable');
 end
end

parts={};records={};
allowed=[".csv",".txt",".tsv",".xls",".xlsx",".mat",".mpt",".dta"];
if settings.ImportMode=="template",allowed=[".csv",".txt",".tsv",".xls",".xlsx"];end
for k=1:numel(files)
    file=files(k);[~,name,ext]=fileparts(file);
    sendProgress(struct('Message',"파일 읽기 "+k+" / "+numel(files)+" · 입력 "+numel(parts)+"개 확보 · "+file));
    record=struct('file',file,'sheet',"",'status',"skipped",'rows',0,'profile',"",'message',"측정 입력 지원 형식 외 파일");
    if any(file==sidecars)
        record.status="metadata";record.message="연구 패키지의 조건·셀·출처 정보 (신호 파일에 연결)";
        records{end+1,1}=record;continue
    end
    if ismember(lower(ext),allowed)&&~startsWith(name,".")
        try
            if lower(ext)==".mat"
                variables=whos('-file',file);
                if ismember('bundle',string({variables.name}))
                    record.message="저장 세션 파일";records{end+1,1}=record;continue
                end
            end
            opts=settings;
            if strlength(paired(k))>0,opts.ImportMode="template";end
            [items,log]=uecm.readMeasurementFile(file,opts);
            for j=1:numel(items)
                if items{j}.Synthetic
                    hit=log.sheet==items{j}.SourceSheet;
                    log.status(hit)="skipped";log.message(hit)="가상 연습 자료";
                else
                    parts{end+1,1}=items{j}; %#ok<AGROW>
                end
            end
            records=[records;num2cell(table2struct(log))]; %#ok<AGROW>
            continue
        catch ex
            record.status="unreadable";
            if string(ex.identifier)=="uecm:InputType",record.status="type_mismatch";end
            record.message=string(ex.message);
        end
    end
    records{end+1,1}=record; %#ok<AGROW>
end
if isempty(records),error('uecm:Folder','폴더에 파일이 없습니다.');end
log=struct2table(vertcat(records{:}));
if isempty(parts)
    messages=log.file+" · "+log.sheet+" · "+log.message;
    if numel(messages)>12,messages=[messages(1:12);"전체 "+height(log)+"개 중 처음 12개 내역입니다. 입력 종류와 폴더를 확인하세요."];end
    error('uecm:Folder','측정 입력을 찾지 못했습니다.\n%s',join(messages,newline));
end
input=uecm.combineInputs(parts,settings);
input.ImportFolder=folder;input.ImportLog=log;
end
