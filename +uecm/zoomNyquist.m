function zoomNyquist(ax,z)
%ZOOMNYQUIST Focus on used points/prediction without discarded points driving limits.
x=real(z(:));y=-imag(z(:));good=isfinite(x)&isfinite(y);x=x(good);y=y(good);if isempty(x),return,end
span=max([max(x)-min(x),max(y)-min(y),eps]);pad=.08*span;
xlim(ax,[min(x)-pad,max(x)+pad]);ylim(ax,[min(y)-pad,max(y)+pad]);
end
