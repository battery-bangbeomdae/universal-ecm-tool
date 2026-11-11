function applyCategoryTicks(ax,bundle,x,y,z)
%APPLYCATEGORYTICKS Limit ticks to visible categories with concise literal labels.
fields=[string(x),string(y),string(z)];names=["X","Y","Z"];ax.TickLabelInterpreter='none';
for k=1:3
 ax.(names(k)+"TickMode")='auto';ax.(names(k)+"TickLabelMode")='auto';
 if ~isfield(bundle,'AxisCategories'),continue,end
 j=find(string({bundle.AxisCategories.Field})==fields(k),1);if isempty(j),continue,end
 labels=string(bundle.AxisCategories(j).Values);values=[];
 objects=[findall(ax,'Type','scatter');findall(ax,'Type','line')];
 for n=1:numel(objects)
  v=objects(n).(names(k)+"Data");values=[values;v(:)]; %#ok<AGROW>
 end
 ticks=unique(values(isfinite(values)&values==fix(values)&values>=1&values<=numel(labels)));
 if isempty(ticks),continue,end
 ticks=ticks(unique(round(linspace(1,numel(ticks),min(8,numel(ticks))))));
 short=replace(labels(ticks),newline," ");
 for n=1:numel(short),if strlength(short(n))>24,short(n)=extractBefore(short(n),24)+"…";end,end
 ax.(names(k)+"Tick")=ticks;ax.(names(k)+"TickLabel")=cellstr(short);
end
end
