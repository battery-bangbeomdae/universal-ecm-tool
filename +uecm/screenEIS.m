function report=screenEIS(freq,re,im,settings)
%SCREEN EIS Conservative leave-one-out local quadratic screening in log frequency.
freq=freq(:);re=re(:);im=im(:);o=uecm.withDefaults(settings);n=numel(freq);x=log10(freq(:));z=complex(re(:),im(:));errors=zeros(n,1);local=zeros(n,1);
if o.EISOutlierThreshold<3||o.EISOutlierMaxFraction<0||o.EISOutlierMaxFraction>.2,error('uecm:EISOutlier','이상점 기준은 3 이상, 최대 제외 비율은 0~0.2입니다.');end
eligible=im(:)<=0;
if o.EISOutlierFilter&&nnz(eligible)>=12&&numel(unique(x(eligible)))>=10
 [ux,~,groups]=unique(x(eligible));zz=z(eligible);
 centers=complex(accumarray(groups,real(zz),[],@median),accumarray(groups,imag(zz),[],@median));
 for k=find(eligible)'
  % Repeated-frequency scatter is ambiguous; retain it rather than pruning it.
  if nnz(x==x(k))>1,continue,end
  choices=find(ux~=x(k));[~,order]=sort(abs(ux(choices)-x(k)));ix=choices(order(1:min(7,numel(choices))));
  v=ux(ix)-x(k);A=[ones(numel(v),1),v,v.^2];y=centers(ix);triples=nchoosek(1:numel(v),3);coefs=complex(zeros(size(triples,1),3));
  for j=1:size(triples,1),rows=triples(j,:);coefs(j,:)=(A(rows,:)\y(rows)).';end
  coef=complex(median(real(coefs),1),median(imag(coefs),1)).';
  errors(k)=abs(z(k)-coef(1));local(k)=median(abs(y-A*coef));
 end
end
floorScale=max(median(abs(z))*.005,eps);s=max(1.4826*median(abs(errors-median(errors))),floorScale);
limit=max(median(errors)+o.EISOutlierThreshold*s,o.EISOutlierThreshold*local);
flag=o.EISOutlierFilter&errors>limit;eligible=im(:)<=0;warningText="";
maxCount=floor(nnz(eligible)*o.EISOutlierMaxFraction);
if nnz(flag&eligible)>maxCount||numel(unique(freq(eligible&~flag)))<10
 flag(:)=false;warningText="이상점 후보가 제외 한도를 넘거나 남는 주파수점이 부족하여 통계 자동 제외를 보류했습니다.";
end
% A repeated-frequency cluster is a stability check, not a shape constraint.
unstable=false(n,1);scatterRatio=zeros(n,1);
if o.EISRepeatScatterLimit<=0||o.EISRepeatMaxFraction<0||o.EISRepeatMaxFraction>.3,error('uecm:EISRepeat','반복 구간 허용 산포는 양수, 최대 비율은 0~0.3이어야 합니다.');end
if o.EISRepeatFilter
 for frequency=unique(freq(eligible))'
  rows=find(eligible&freq(:)==frequency);if numel(rows)<5,continue,end
  center=complex(median(real(z(rows))),median(imag(z(rows))));radius=median(abs(z(rows)-center));ratio=radius/max(abs(center),eps);scatterRatio(rows)=ratio;
  if ratio>o.EISRepeatScatterLimit&&radius>o.EISOutlierThreshold*s,unstable(rows)=true;end
 end
 if nnz(unstable)>floor(nnz(eligible)*o.EISRepeatMaxFraction)||numel(unique(freq(eligible&~unstable&~flag)))<10
  unstable(:)=false;warningText=warningText+" 반복 구간 제외 한도/남은 주파수 부족으로 자동 구간 제외를 보류했습니다.";
 end
end
reason=repmat("used",n,1);reason(im(:)>0)="positive_imaginary";reason(flag&eligible)="statistical_outlier";reason(unstable)="unstable_repeated_frequency";
report=table((1:n)',freq(:),re(:),im(:),errors,limit,flag&eligible,im(:)>0,scatterRatio,unstable,reason, ...
 'VariableNames',{'InputIndex','Frequency_Hz','Real_Ohm','Imag_Ohm','LocalDeviation_Ohm','Threshold_Ohm','StatisticalOutlier','PositiveImaginary','RepeatRelativeScatter','UnstableRepeat','Reason'});
report.Properties.UserData=struct('Version',2,'Method',"log-frequency median local quadratic / MAD + repeated-frequency stability",'Threshold',o.EISOutlierThreshold,'Warning',warningText);
end
