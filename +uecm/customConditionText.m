function text=customConditionText(bundle,row)
%CUSTOMCONDITIONTEXT Explicit registered conditions, separate from measured SOC/T.
text="";if ~isfield(bundle,'CustomAxes')||isempty(bundle.CustomAxes),return,end
parts=strings(0,1);
axes=bundle.CustomAxes;imported=startsWith(string({axes.Source}),"imported:");axes=[axes(~imported),axes(imported)];
for a=axes
 label=a.Label;if strlength(a.Unit)>0,label=label+" ["+a.Unit+"]";end
 value="미연결";if ismember(a.Field,string(row.Properties.VariableNames))&&isfinite(row.(a.Field)),value=uecm.axisValueLabel(bundle,a.Field,row.(a.Field));end
 parts(end+1)=label+"="+value; %#ok<AGROW>
end
text="추가 실험 조건: "+join(parts," · ");
end
