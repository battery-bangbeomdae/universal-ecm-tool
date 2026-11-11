function [bundle,message]=workspaceFit(input,old,compute,progress,p)
if nargin<5,p=uecm.prepare(input);end
if isstruct(old),old=uecm.fittingPieces(old);end
parts={p};if isfield(p,'FilePrepared'),parts=p.FilePrepared;end
pieces=cell(size(parts));reused=0;made=0;failed=0;notes=strings(0,1);
% Cache validity includes every application source byte and MATLAB release.
files=dir(fullfile(fileparts(mfilename('fullpath')),'**','*.m'));signature=string(version);
for n=1:numel(files),signature(end+1,1)=string(fileread(fullfile(files(n).folder,files(n).name)));end
roots=strings(size(parts));
for k=1:numel(parts)
 if isfield(parts{k}.Input,'FittingRoot'),roots(k)=uecm.fitCacheSearchRoot(parts{k}.Input.FittingRoot);end
end
diskPieces=uecm.readFitCaches(parts,roots,signature);dirtyRoots=strings(0,1);
for k=1:numel(parts)
 q=parts{k};piece=diskPieces{k};cache="";
 if isfield(q.Input,'FittingRoot')
  bytes=unicode2native(char(q.Input.File),'UTF-8');h1=0;h2=0;
  for byte=double(bytes),h1=mod(h1*31+byte,1000000007);h2=mod(h2*37+byte,1000000009);end
  id=sprintf('%09d_%09d',h1,h2);cache=fullfile(q.Input.FittingRoot,id);
  currentRoot=uecm.fitCacheSearchRoot(q.Input.FittingRoot);
  % A prior fit may create a more-specific root or append a newer snapshot.
  % Rescan only affected pending inputs so sequential save/reuse stays intact.
  if currentRoot~=roots(k)||ismember(currentRoot,dirtyRoots)
   refreshed=uecm.readFitCaches({q},currentRoot,signature);piece=refreshed{1};
  end
 end
 for j=1:numel(old)
  if uecm.fitArchiveMatches(old{j},q),piece=uecm.mergeEISArchives(piece,old{j});end
 end
 missing=[];if q.Type=="EIS",missing=uecm.missingEISModels(piece,q);end
 needs=isempty(piece)||(q.Type=="EIS"&&~isempty(missing));
 if ~isempty(piece),reused=reused+1;end
 if compute&&~q.Blocked&&needs
  progress(struct('Message',"피팅 "+k+" / "+numel(parts)));
  run=q;
  if q.Type=="EIS",run.Input.Settings.Circuit="auto";run.Input.Settings.EISModels=missing;types=uecm.eisFitTypes(q.Input.Settings);run.Input.Settings.EISAutoWarburg=any(endsWith(types,"+W"));end
  fresh=uecm.analyze(run.Input,progress,run);piece=uecm.mergeEISArchives(piece,fresh);made=made+1;
  piece.Prepared=q;
  if strlength(cache)>0&&~isempty(piece.Results)
   temporary="";
   try
    if ~isfolder(cache),mkdir(cache);end
    temporary=string(tempname(cache))+".partial.mat";local=piece;bundle=local; %#ok<NASGU>
    uecm.saveFittingSnapshot(temporary,bundle,signature);
    [~,uniqueName]=fileparts(tempname(cache));destination=fullfile(cache,"fit_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))+"_"+uniqueName+".mat");
    movefile(temporary,destination);
    affected=roots(strlength(roots)>0&arrayfun(@(r)startsWith(string(destination),r+filesep),roots));
    dirtyRoots=union(dirtyRoots,[affected(:);string(q.Input.FittingRoot)],'stable');
   catch ex
    failed=failed+1;notes(end+1)=string(ex.message);
    if strlength(temporary)>0&&isfile(temporary),delete(temporary);end
   end
  end
 end
 pieces{k}=piece;
end
bundle=uecm.mergeFittingPieces(p,pieces);
message="재사용 "+reused+"개 파일 / 새 피팅 "+made+"개 파일 / 백업 실패 "+failed+"개";
bundle.CacheSummary=message;bundle.CacheWarnings=notes;
end
