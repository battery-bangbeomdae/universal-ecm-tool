function [x,y]=segmentPlotRows(x,y,breaks)
%SEGMENTPLOTROWS Insert NaN separators without sorting or inventing samples.
x=x(:);y=y(:);breaks=logical(breaks(:));n=numel(x);
if n==0,return,end
breaks(1)=false;positions=(1:n)'+cumsum(breaks);
xx=nan(n+sum(breaks),1);yy=nan(size(xx));
xx(positions)=x;yy(positions)=y;x=xx;y=yy;
end
