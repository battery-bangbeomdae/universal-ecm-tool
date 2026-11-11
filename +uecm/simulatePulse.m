function voltage = simulatePulse(time,current,baseline,R0,R,tau)
%SIMULATEPULSE Exact ZOH RC response, same zero-state/baseline for every model.
arguments
    time (:,1) double
    current (:,1) double
    baseline (1,1) double
    R0 (1,1) double
    R double
    tau double
end
voltage=baseline-R0*current;dt=diff(time);
uniform=~isempty(dt)&&max(abs(dt-dt(1)))<=max(1e-10,abs(dt(1))*1e-8);
for j=1:numel(R)
    if uniform
        a=exp(-dt(1)/tau(j));state=filter([0,R(j)*(1-a)],[1,-a],current);
    else
        state=zeros(size(time));
        for k=2:numel(time)
            a=exp(-dt(k-1)/tau(j));state(k)=a*state(k-1)+R(j)*(1-a)*current(k-1);
        end
    end
    voltage=voltage-state;
end
end
