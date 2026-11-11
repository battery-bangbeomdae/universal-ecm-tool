function missing=missingEISModels(piece,q)
%MISSINGEISMODELS Require coverage for every measurable spectrum, not just one.
types=uecm.eisFitTypes(q.Input.Settings);families=unique(erase(types,"+W"),'stable');missing=families;
if isempty(piece)||isempty(piece.Fits),return,end
T=q.Data;keys=T.source+"|"+T.cell+"|"+T.test+"|"+T.spectrum;
[~,first]=unique(keys,'stable');
% Build identities once instead of scanning every saved fit for every spectrum.
fitKeys=strings(numel(piece.Fits),4);
for j=1:numel(piece.Fits)
 id=piece.Fits{j}.Identity;
 fitKeys(j,:)=[string(id.source_id),string(id.cell_id),string(id.test_id),string(id.spectrum_id)];
end
required=[T.source(first),T.cell(first),T.test(first),T.spectrum(first)];
if ~all(ismember(required,fitKeys,'rows')),return,end
complete=true(size(families));
for j=1:numel(piece.Fits)
 f=piece.Fits{j};evaluated=strings(1,0);
 if isfield(f,'EvaluatedModels'),evaluated=string(f.EvaluatedModels);end
 for k=1:numel(families)
  required=types(erase(types,"+W")==families(k));complete(k)=complete(k)&&all(ismember(required,evaluated));
 end
end
missing=families(~complete);
end
