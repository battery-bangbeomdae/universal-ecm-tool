function [parts,log]=readMeasurementFile(file,settings,metadataFile)
%READMEASUREMENTFILE Read a file or independent measurement sheets, logging partial failures.
arguments
    file (1,1) string
    settings (1,1) struct = uecm.defaults()
    metadataFile (1,1) string = ""
end
settings=uecm.withDefaults(settings);[~,~,ext]=fileparts(file);
parts={};records={};
if ismember(lower(ext),[".xlsx",".xls"])&&strlength(settings.Sheet)==0
    sheets=sheetnames(file);
else
    sheets=settings.Sheet;
end
splitSheets=numel(sheets)>1;
for k=1:numel(sheets)
    opts=settings;opts.Sheet=sheets(k);
    record=struct('file',file,'sheet',sheets(k),'status',"loaded",'rows',0,'profile',"",'message',"가져옴");
    try
        item=uecm.readInput(file,opts,metadataFile);m=item.Mapping;has=@(f)strlength(m.(f))>0;
        eis=has('frequency')&&((has('real')&&has('imag'))||(has('magnitude')&&has('phase')));
        pulse=has('time')&&has('current')&&has('voltage');
        if ~eis&&~pulse,error('uecm:InputType','EIS 또는 시간·전류·전압 측정 열 조합을 찾지 못했습니다.');end
        if splitSheets,item.File=file+"#uecm_sheet="+sheets(k);end
        parts{end+1,1}=item; %#ok<AGROW>
        record.file=item.SourceFile;record.sheet=item.SourceSheet;
        record.rows=height(item.Data);record.profile="template";
        if isfield(item,'RawReport')
            record.profile=item.RawReport.Profile;
            if ~isempty(item.RawReport.Requests),record.message=join(item.RawReport.Requests," / ");end
        end
    catch ex
        record.status="unreadable";
        if string(ex.identifier)=="uecm:InputType",record.status="type_mismatch";end
        record.message=string(ex.message);
        if ~splitSheets,rethrow(ex);end
    end
    records{end+1,1}=record; %#ok<AGROW>
end
log=struct2table(vertcat(records{:}));
if isempty(parts)
    messages=log.sheet+" · "+log.message;
    error('uecm:WorkbookInputs','읽을 수 있는 측정 시트가 없습니다.\n%s',join(messages(1:min(12,end)),newline));
end
end
