function sweep = sweepIndex(f)
%SWEEPINDEX Sweep (spectrum) number for each row of a frequency column that has no spectrum ID.
% One rule for BOTH input paths (raw reader and tidy/template tables), so the same file is split the same way.
%   1) main sweep direction = sign of the median non-zero frequency step (high->low or low->high);
%   2) a new sweep starts at a step that goes AGAINST the main direction, or at a jump > 1.5 decades.
% Each boundary is counted once. (Up to 2026-11-09 the rule was "rise after fall OR jump", which counted every
% boundary of a low->high sweep twice and created one-point spectra; found with Zhu 2022 hold-out data.)
f=double(f(:));n=numel(f);sweep=ones(n,1);
if n<2,return,end
% 2026-11-10: boundaries are judged on valid rows only (finite, > 0 Hz). A blank row or a DC 0 Hz point used to
% count as a 300-decade "jump" and split one spectrum into 3 pieces; such rows now inherit the previous sweep.
ok=isfinite(f)&f>0;g=f(ok);
if numel(g)<2,return,end
d=diff(g);nz=d(d~=0);
if isempty(nz),return,end
if median(nz)<0,against=d>0;else,against=d<0;end
jump=abs(diff(log10(g)))>1.5;
sv=cumsum([1;against|jump]);
sweep(ok)=sv;idx=find(ok);
for k=find(~ok)'
    p=idx(find(idx<k,1,'last'));if isempty(p),sweep(k)=sv(1);else,sweep(k)=sweep(p);end
end
end
