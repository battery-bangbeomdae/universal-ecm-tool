function result=mergeEISArchives(result,next)
%MERGEEISARCHIVES Union model candidates; later snapshots replace the same family.
if isempty(result),result=next;return,end
if result.Prepared.Type~="EIS",result=next;return,end
for j=1:numel(next.Fits)
 incoming=next.Fits{j};id=table2struct(next.Results(j,:));hit=[];
 for k=1:numel(result.Fits)
  f=result.Fits{k};a=f.Identity;
  if a.source_id==id.source_id&&a.cell_id==id.cell_id&&a.test_id==id.test_id&&a.spectrum_id==id.spectrum_id&&isequal(f.SourceRows,incoming.SourceRows)
   hit=k;break
  end
 end
 if isempty(hit)
  result.Fits{end+1,1}=incoming;result.Results=combineRows(result.Results,next.Results(j,:));continue
 end
 previous=result.Fits{hit};oldIdentity=table2struct(result.Results(hit,:));
 for field=string(fieldnames(oldIdentity))'
  if startsWith(field,"custom_")&&~isfield(id,field),id.(field)=oldIdentity.(field);end
 end
 candidates=uecm.candidatesOf(previous);more=uecm.candidatesOf(incoming);
 for n=1:numel(more)
  family=erase(string(more{n}.Candidate),"+W");at=find(cellfun(@(c)erase(string(c.Candidate),"+W")==family,candidates),1);
  if isempty(at),candidates{end+1,1}=more{n};else,candidates{at}=more{n};end
 end
 selected=uecm.compareCandidates(candidates);
 selected.SourceRows=incoming.SourceRows;selected.SourceFile=incoming.SourceFile;
 evaluated=strings(1,0);
 for item={previous,incoming}
  f=item{1};if isfield(f,'EvaluatedModels'),evaluated=union(evaluated,string(f.EvaluatedModels),'stable');end
 end
 selected.EvaluatedModels=evaluated;selected.Identity=uecm.candidateRow(id,selected);
 for n=1:numel(selected.Alternatives),selected.Alternatives{n}.Identity=uecm.candidateRow(id,selected.Alternatives{n});end
 result.Fits{hit}=selected;aligned=combineRows(result.Results,struct2table(selected.Identity));result.Results=aligned(1:end-1,:);result.Results(hit,:)=aligned(end,:);
end
if isfield(next,'CustomAxes')
 for entry=next.CustomAxes
  hit=find(string({result.CustomAxes.Field})==entry.Field,1);
  if isempty(hit),result.CustomAxes(end+1)=entry;else,result.CustomAxes(hit)=entry;end
 end
end
result.Prepared.Requests=unique([result.Prepared.Requests;next.Prepared.Requests],'rows','stable');
end

function T=combineRows(A,B)
% Batch harmonization can add condition columns absent from an older snapshot.
names=union(string(A.Properties.VariableNames),string(B.Properties.VariableNames),'stable');
for name=names
 if ~ismember(name,string(A.Properties.VariableNames)),A.(name)=missingLike(B.(name),height(A));end
 if ~ismember(name,string(B.Properties.VariableNames)),B.(name)=missingLike(A.(name),height(B));end
end
T=[A(:,cellstr(names));B(:,cellstr(names))];
end
function values=missingLike(example,n)
if isstring(example),values=strings(n,1);elseif islogical(example),values=false(n,1);else,values=nan(n,1);end
end
