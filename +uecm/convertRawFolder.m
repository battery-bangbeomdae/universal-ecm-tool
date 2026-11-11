function [T, log] = convertRawFolder(folder, outCsv, pattern, settings)
%CONVERTRAWFOLDER Read every raw file in a folder with uecm.readRaw and write ONE canonical CSV for the app.
%   [T,log]=uecm.convertRawFolder('DIB_Data/.matfiles/EIS_Test','LGM50_EIS_raw.csv','*.mat')
% Values are not changed. Each file keeps its own source_id (file name); conditions come from the data or,
% if absent, from explicit file-name tokens (see readRaw). log lists profile, kind, rows and open requests per file.
arguments
    folder (1,1) string
    outCsv (1,1) string
    pattern (1,1) string = "*.*"
    settings (1,1) struct = uecm.defaults()
end
[outputParent,outputStem]=fileparts(outCsv);if outputParent=="",outputParent=string(pwd);end
uecm.validateOutputParent(outputParent);
if isfile(outCsv)||isfile(fullfile(outputParent,outputStem+"_import_log.csv")),error('uecm:OutputExists','출력 파일이 이미 있습니다. 새 이름을 사용하세요.');end
files=dir(fullfile(folder,pattern));files=files(~[files.isdir]);
[~,outStem,outExt]=fileparts(outCsv);
own=[outStem+outExt,outStem+"_import_log.csv"];
files=files(~ismember(string({files.name}),own)&~startsWith(string({files.name}),["~$","."])&~strcmpi(string({files.name}),"desktop.ini"));   % never re-read our own output / Office lock / system files
if isempty(files),error('uecm:Folder','%s 에 %s 파일이 없습니다.',folder,pattern);end
parts=cell(numel(files),1);rows=cell(numel(files),1);
for k=1:numel(files)
    f=string(fullfile(files(k).folder,files(k).name));
    try
        [P,r]=uecm.readRaw(f,settings);parts{k}=P;
        rows{k}=struct('file',string(files(k).name),'profile',r.Profile,'kind',r.Kind,'rows',height(P), ...
            'requests',strjoin(r.Requests," / "),'hints',strjoin(unique(r.Hints)," / "));
    catch ex
        rows{k}=struct('file',string(files(k).name),'profile',"",'kind',"error",'rows',0,'requests',string(ex.message),'hints',"");
    end
end
log=struct2table(vertcat(rows{:}));
ok=~cellfun(@isempty,parts);
if ~any(ok),error('uecm:Folder','읽을 수 있는 파일이 없습니다. log를 확인해 주세요.');end
kinds=unique(log.kind(ok));
if numel(kinds)>1,error('uecm:Folder','EIS와 시계열 파일이 섞여 있습니다: %s. pattern으로 나눠 주세요.',strjoin(kinds,", "));end
nm=cellfun(@(t)string(t.Properties.VariableNames),parts(ok),'UniformOutput',false);
names=unique([nm{:}],'stable');
for k=find(ok)'
    miss=setdiff(names,string(parts{k}.Properties.VariableNames));
    for m=miss
        parts{k}.(m)=missingLike(parts,m,height(parts{k}));
    end
    parts{k}=parts{k}(:,cellstr(names));
end
for m=names                                                          % same column, different types across files -> string
    isNum=cellfun(@(t)isnumeric(t.(m))||islogical(t.(m)),parts(ok));
    if any(isNum)&&~all(isNum),for k=find(ok)',parts{k}.(m)=string(parts{k}.(m));end,end
end
T=vertcat(parts{ok});
writetable(T,outCsv,'Encoding','UTF-8');
[p,s]=fileparts(outCsv);writetable(log,fullfile(p,s+"_import_log.csv"),'Encoding','UTF-8');
end

function v=missingLike(parts,name,n)
for k=1:numel(parts)
    if ~isempty(parts{k})&&ismember(name,string(parts{k}.Properties.VariableNames))
        x=parts{k}.(name);
        if isnumeric(x),v=nan(n,1);else,v=strings(n,1);end
        return
    end
end
v=nan(n,1);
end
