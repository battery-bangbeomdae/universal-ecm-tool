function pieces=fittingPieces(bundle)
%FITTINGPIECES Convert workspace fits to independent file-local snapshots.
pieces={};if ~isfield(bundle,'Prepared')||~isfield(bundle,'Results')||isempty(bundle.Results),return,end
p=bundle.Prepared;parts={p};if isfield(p,'FilePrepared'),parts=p.FilePrepared;end
offset=0;
for k=1:numel(parts)
 q=parts{k};rows=find(string(bundle.Results.source_file)==string(q.Input.File));
 if ~isempty(rows)
  piece=bundle;piece.Prepared=q;piece.Results=bundle.Results(rows,:);piece.Fits=bundle.Fits(rows);
  for j=1:numel(piece.Fits)
   f=piece.Fits{j};f.SourceRows=f.SourceRows-offset;
   if isfield(f,'Alternatives'),for a=1:numel(f.Alternatives),f.Alternatives{a}.SourceRows=f.Alternatives{a}.SourceRows-offset;end,end
   piece.Fits{j}=f;
  end
  for field=["CacheReport","CacheSummary"],if isfield(piece,field),piece=rmfield(piece,field);end,end
  pieces{end+1}=piece; %#ok<AGROW>
 end
 offset=offset+height(q.Input.Data);
end
end
