function [N,defs,categories]=importConditionAxes(N,input)
%IMPORTCONDITIONAXES Retain additional scalar columns using validated identity joins.
defs=struct('Field',{},'Label',{},'Unit',{},'Source',{},'Column',{},'Keys',{},'LinkedCount',{},'MissingCount',{});
categories=struct('Field',{},'Values',{});
T=input.Data;M=input.Metadata;mapping=input.Mapping;
used=string(struct2cell(mapping));used=used(strlength(used)>0);
names=string(T.Properties.VariableNames);extra=names(~ismember(names,used)&~startsWith(names,"uecm_"));
extra=extra(~startsWith(extra,"raw_"));   % raw-converter bookkeeping (raw_source_row, raw_step, raw_sheet...) is provenance, not a condition
joined=table();
for col=extra
 v=T.(col);if size(v,2)==1,joined.(col)=v;end
end
if ~isempty(M)
 mm=uecm.inferMapping(M.Properties.VariableNames);ids=["source","cell","test","spectrum"];
 common=ids(arrayfun(@(f)strlength(mapping.(f))>0&&strlength(mm.(f))>0,ids));
 if any(ismember(common,["test","spectrum"]))
  A=strings(height(N),numel(common));B=strings(height(M),numel(common));
  for k=1:numel(common),A(:,k)=N.(common(k));B(:,k)=string(M.(mm.(common(k))));end
  if height(unique(B,'rows'))==height(M)
   [found,loc]=ismember(A,B,'rows');found=found&~any(ismissing(A)|strlength(strip(A))==0,2);
   usedMeta=string(struct2cell(mm));cols=string(M.Properties.VariableNames);
   cols=cols(~ismember(cols,usedMeta)&~startsWith(cols,"uecm_"));
   for col=cols
    v=M.(col);if size(v,2)~=1,continue,end
    if isnumeric(v)||islogical(v),z=nan(height(N),1);z(found)=double(v(loc(found)));
    else,z=strings(height(N),1);z(:)=missing;z(found)=string(v(loc(found)));end
    if ismember(col,string(joined.Properties.VariableNames))
     a=string(joined.(col));b=string(z);known=~ismissing(a)&strlength(strip(a))>0&lower(a)~="nan";
     other=~ismissing(b)&strlength(strip(b))>0&lower(b)~="nan";
     clash=known&other&a~=b;a(~known)=b(~known);a(clash)=missing;joined.(col)=a;
    else,joined.(col)=z;end
   end
  end
 end
end
for col=string(joined.Properties.VariableNames)
 raw=joined.(col);label=col;
 field=string(matlab.lang.makeValidName("custom_"+col));
 if ismember(field,string({defs.Field})),error('uecm:AxisNameCollision','추가 열 이름이 충돌합니다: %s',col);end
 if isnumeric(raw)||islogical(raw)
  v=double(raw);
 else
  s=strip(string(raw));blank=ismissing(s)|strlength(s)==0|lower(s)=="nan";
  [values,~,code]=unique(s(~blank),'sorted');parsed=str2double(values);
  if numel(values)>max(50,0.01*height(N))&&any(isnan(parsed)),continue,end   % per-row text (timestamps, comments) is not a condition axis
  v=nan(height(N),1);
  if all(~isnan(parsed)),v(~blank)=parsed(code);
  else
   v(~blank)=double(code);categories(end+1)=struct('Field',field,'Values',values);label=col+" (범주)";
  end
 end
 v(~isfinite(v))=NaN;if ~any(isfinite(v)),continue,end
 N.(field)=v;
 defs(end+1)=struct('Field',field,'Label',label,'Unit',"",'Source',"imported:"+string(input.File), ...
  'Column',col,'Keys',["source_id","cell_id","test_id","spectrum_id"],'LinkedCount',nnz(isfinite(v)),'MissingCount',nnz(~isfinite(v)));
end
end
