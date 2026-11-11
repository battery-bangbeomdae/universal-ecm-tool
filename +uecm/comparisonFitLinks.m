function [matched,j]=comparisonFitLinks(T,bundle)
%COMPARISONFITLINKS Exact source/trace identity, plus HPPC onset source row.
matched=false(height(T),1);j=zeros(height(T),1);
if isempty(T)||~isfield(bundle,'Results')||isempty(bundle.Results),return,end
R=bundle.Results;
fields=["source_file","source_id","cell_id","test_id","spectrum_id","domain"];
A=strings(height(T),7);B=strings(height(R),7);
for k=1:numel(fields)
 f=fields(k);tf=f;if f=="spectrum_id",tf="measurement_id";end
 if ~ismember(tf,string(T.Properties.VariableNames))||~ismember(f,string(R.Properties.VariableNames))
  return
 end
 A(:,k)=string(T.(tf));B(:,k)=string(R.(f));
end
A(:,7)="EIS";B(:,7)="EIS";
for k=find(T.domain=="HPPC")'
 A(k,7)="unlinked_curve_"+k;
 if ismember('onset_source_row',T.Properties.VariableNames)&&isfinite(T.onset_source_row(k)),A(k,7)=string(T.onset_source_row(k));end
end
for k=find(R.domain=="HPPC")'
 B(k,7)="unlinked_fit_"+k;
 if isfield(bundle,'Fits')&&k<=numel(bundle.Fits)&&isfield(bundle.Fits{k},'SourceRows')&&~isempty(bundle.Fits{k}.SourceRows)
  B(k,7)=string(bundle.Fits{k}.SourceRows(1));
 end
end
[~,~,g]=unique(B,'rows');counts=accumarray(g,1);ambiguous=counts(g)>1;
[matched,j]=ismember(A,B,'rows');rows=find(matched);matched(rows(ambiguous(j(rows))))=false;
end
