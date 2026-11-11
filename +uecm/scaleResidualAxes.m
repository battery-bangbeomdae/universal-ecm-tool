function scaleResidualAxes(ax)
%SCALERESIDUALAXES Make small errors visible, retaining the physical unit.
curves=findall(ax,'Type','line');values=[];
for k=1:numel(curves),v=curves(k).YData;v=v(:);values=[values;v(isfinite(v))];end
if isempty(values),return,end
lo=min(0,min(values));hi=max(0,max(values));pad=max((hi-lo)*.1,eps);
ylim(ax,[lo-pad,hi+pad]);ytickformat(ax,'%.3g');
end
