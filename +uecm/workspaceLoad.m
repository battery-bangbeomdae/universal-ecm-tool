function out=workspaceLoad(files,settings,meta,current,bundle,mode,sendProgress)
if nargin<6,mode="append";end
if nargin<7,sendProgress=@(~)[];end
incoming=uecm.Models.SessionModel.loadFile(files,settings,meta,sendProgress);
if isfield(incoming,'SavedSession')&&(isempty(fieldnames(current))||mode=="session")
 incoming.Input=incoming.Bundle.Prepared.Input;out=incoming;return
end
extra={};if isfield(incoming,'SavedSession')
 extra=uecm.fittingPieces(incoming.Bundle);incoming=incoming.Bundle.Prepared.Input;
 if isempty(fieldnames(current)),settings=incoming.Settings;end
end
new=uecm.effectiveInputs(incoming);
for k=1:numel(new)
 root=fileparts(extractBefore(string(new{k}.File)+"#","#"));
 for f=string(files(:))',if isfolder(f)&&startsWith(string(new{k}.File),f+filesep),root=f;end,end
 new{k}.FittingRoot=uecm.fittingRootForInput(string(new{k}.File),string(root));
end
parts={};if ~isempty(fieldnames(current)),parts=uecm.effectiveInputs(current);end
for k=1:numel(new)
 hit=find(cellfun(@(x)string(x.File)==string(new{k}.File),parts),1);
 if isempty(hit),parts{end+1}=new{k};
 elseif mode=="reload"||~isequaln(parts{hit}.Data,new{k}.Data)||~isequaln(parts{hit}.Metadata,new{k}.Metadata)
  parts{hit}=new{k};
 end
end
flags=cellfun(@(x)x.Synthetic,parts);if any(flags)&&~all(flags),error('uecm:Mixed','가상 자료와 실제 자료는 함께 추가할 수 없습니다.');end
if ~isempty(fieldnames(current)),settings=current.Settings;end
if numel(parts)==1,input=parts{1};input.Settings=settings;
else
 input=uecm.combineInputs(parts,settings);input.Settings.Type="auto";
 options=struct('File',{},'Type',{},'CurrentSign',{});
 for k=1:numel(parts),options(k)=struct('File',string(parts{k}.File),'Type',string(parts{k}.Settings.Type),'CurrentSign',string(parts{k}.Settings.CurrentSign));end
 input.Settings.FileOptions=options;
end
% Keep import audit/root context when flattening/recombining source inputs.
logs={};roots=strings(0,1);
for origin={current,incoming}
 item=origin{1};
 if isfield(item,'ImportLog'),logs{end+1}=item.ImportLog;end
 if isfield(item,'ImportFolder'),roots=union(roots,string(item.ImportFolder(:)),'stable');end
end
if ~isempty(logs)
 log=vertcat(logs{:});[~,keep]=unique(log(:,{'file','sheet'}),'rows','last');input.ImportLog=log(sort(keep),:);
end
if ~isempty(roots),input.ImportFolder=roots;end
sendProgress(struct('Message',"입력 "+numel(parts)+"개 정규화 및 조건 연결 중"));
prepared=uecm.prepare(input);old=[uecm.fittingPieces(bundle),extra];
[b,report]=uecm.workspaceFit(input,old,false,@(~)[],prepared);
message="입력 총 "+numel(parts)+"개를 불러왔습니다. "+height(b.Results)+"개 피팅 결과 재사용. "+report;
if isfield(incoming,'ImportLog')
 L=incoming.ImportLog;message=message+" · 이번 읽기 성공 "+sum(L.status=="loaded")+" / 부가정보 "+sum(L.status=="metadata")+" / 실패·제외 "+sum(~ismember(L.status,["loaded","metadata"]))+" (데이터·파일·축 정보 → 폴더 가져오기 내역)";
end
out=struct('LoadedWorkspace',true,'Input',input,'Bundle',b,'Message',message);
end
