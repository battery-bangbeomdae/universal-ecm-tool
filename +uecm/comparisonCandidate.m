function c=comparisonCandidate(data,curveID,model)
%COMPARISONCANDIDATE Only the requested saved model; no fallback or recomputation.
c=[];if ~isfield(data,'FitCandidates')||curveID>numel(data.FitCandidates),return,end
cc=data.FitCandidates{curveID};if isempty(cc),return,end
if model=="권장 모델"
 k=min(numel(cc),max(1,data.RecommendedCandidate(curveID)));c=cc{k};
else
 for k=1:numel(cc),if string(cc{k}.ModelName)==model,c=cc{k};return,end,end
end
end
