function plotExcludedEIS(ax,c,label)
%PLOTEXCLUDEDEIS Show original excluded measurements separately from fit data.
if nargin<3,label="";end
if ~isfield(c,'Preprocessing')||isempty(c.Preprocessing),return,end
R=c.Preprocessing;
for reason=["positive_imaginary","statistical_outlier","unstable_repeated_frequency"]
 hit=R.Reason==reason;if ~any(hit),continue,end
 text="제외 · Im(Z)>0";ink=[.55,.55,.55];if reason=="statistical_outlier",text="제외 · 통계 이상점";ink=[.85,.35,.15];end
 if reason=="unstable_repeated_frequency",text="제외 · 반복 구간 불안정";ink=[.65,.35,.8];end
 plot(ax,R.Real_Ohm(hit),-R.Imag_Ohm(hit),'x','LineStyle','none','Color',ink,'MarkerSize',7,'LineWidth',1.3,'DisplayName',label+text,'Tag',"EISExcluded_"+reason);
end
end
