function match=fitArchiveMatches(piece,q)
%FITARCHIVEMATCHES Model families may accumulate only for identical data/profiles.
match=uecm.fitPieceMatches(piece,q,false);if ~match,return,end
if q.Type~="EIS",match=uecm.fitPieceMatches(piece,q);return,end
for k=1:numel(piece.Fits),if ~isfield(piece.Fits{k},'PreprocessingVersion')||piece.Fits{k}.PreprocessingVersion~=2,match=false;return,end,end
a=profile(piece.Prepared.Input.Settings);b=profile(q.Input.Settings);match=isequaln(a,b);
end
function value=profile(settings)
value=uecm.fitConfiguration(settings);types=uecm.eisFitTypes(settings);
value.EISAutoWarburg=any(endsWith(types,"+W"));value=rmfield(value,{'Circuit','EISModels'});
end
