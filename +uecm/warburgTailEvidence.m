function [supported,sigma,upperFrequency] = warburgTailEvidence(frequency,z)
% Test whether the measured low-frequency tail follows the semi-infinite W law.
[frequency,~,group]=unique(frequency(:));
z=z(:);
realZ=accumarray(group,real(z),[],@median);
loss=accumarray(group,-imag(z),[],@median);
count=min(numel(frequency),max(5,ceil(numel(frequency)/4)));
supported=false;
sigma=NaN;
upperFrequency=NaN;
if count<5||frequency(count)/frequency(1)<3,return,end
x=1./sqrt(2*pi*frequency(1:count));
y=[realZ(1:count),loss(1:count)];
coeff=[ones(count,1),x]\y;
variation=sum((y-mean(y,1)).^2,1);
rSquared=1-sum((y-[ones(count,1),x]*coeff).^2,1)./max(variation,realmin);
slopes=coeff(2,:);
supported=all(slopes>0)&&min(slopes)/max(slopes)>=0.7&&all(rSquared>=0.95);
if supported
    sigma=mean(slopes);
    upperFrequency=frequency(count);
end
end
