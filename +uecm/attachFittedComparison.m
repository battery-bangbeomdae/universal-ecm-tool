function data=attachFittedComparison(data,bundle,links)
%ATTACHFITTEDCOMPARISON Reference saved candidates, never run a solver.
T=data.Measurements;n=height(T);data.FitCandidates=cell(n,1);data.RecommendedCandidate=ones(n,1);
T.fit_id=repmat("",n,1);
if nargin<3,[matched,index]=uecm.comparisonFitLinks(T,bundle);else,matched=links.Matched;index=links.Index;end
for k=find(matched)'
 j=index(k);if ~isfield(bundle,'Fits')||j>numel(bundle.Fits),continue,end
 f=bundle.Fits{j};if ~isfield(f,'Predicted'),continue,end
 candidates=uecm.candidatesOf(f);data.FitCandidates{k}=candidates;
 if isfield(f,'RecommendedIndex'),data.RecommendedCandidate(k)=f.RecommendedIndex;end
 if ismember('fit_id',bundle.Results.Properties.VariableNames),T.fit_id(k)=string(bundle.Results.fit_id(j));end
end
data.Measurements=T;
end
