function s = socFromAnchors(time, currentCharge, voltage, settings)
%SOCFROMANCHORS SOC from the test itself: 100 % at the end of a CC-CV full charge, capacity from the charge that
% follows a full discharge (empty -> full) in the same continuous record. Coulomb counting, efficiency 1.
%   currentCharge : CHARGE-POSITIVE current [A]
% Rules (all deterministic, reported in s.Message):
%   full anchor  = first charge step >= 600 s whose last 10 % is constant voltage (std < 2 mV) with tapering current
%                  (mean < 50 % of its CC level) and that ends at <= 20 % of the CC level
%   empty anchor = last discharge step >= 600 s before it that ends within 50 mV of the record's lowest voltage
%   capacity     = charge integrated from empty end to full end; else settings.Capacity_Ah; else not computed
%   rest current (|I| <= rest threshold, same as fitHPPC) is integrated as zero: Wuppertal MCU1 reads +21 mA during
%   2.5 h rests while the voltage falls (4.199 -> 4.180 V), i.e. an offset, not charge (it would add +1.06 % SOC).
% Checked on Wuppertal Samsung 50E Batch1 MCU1-8 (full raw files): capacity 4.828-4.932 Ah, SOC after the final
% discharge to cutoff between -0.79 and +1.12 % (closure error; MCU1 -0.20 %).
arguments
    time (:,1) double
    currentCharge (:,1) double
    voltage (:,1) double
    settings (1,1) struct = uecm.defaults()
end
o=uecm.withDefaults(settings);n=numel(time);
s=struct('SOC',nan(n,1),'Found',false,'Capacity_Ah',NaN,'CapacitySource',"",'FullAnchor_s',NaN,'EmptyAnchor_s',NaN, ...
    'ClosureSOC_pct',NaN,'Message',"");
if n<100||any(diff(time)<0)||any(~isfinite(time)),s.Message="SOC 자동 계산 불가: 시간 순서가 연속이 아닙니다.";return,end
i=currentCharge;i(~isfinite(i))=0;v=voltage;
thr=min(max(abs(i))*.02,.05);
if isfinite(o.RestCurrent_A)&&o.RestCurrent_A>0,thr=o.RestCurrent_A;end
act=abs(i)>thr;st=find(diff([false;act])==1);en=find(diff([act;false])==-1);
full=[];empty=[];vmin=min(v(isfinite(v)));
for k=1:numel(st)
    a=st(k);b=en(k);if b-a<50||time(b)-time(a)<600||median(i(a:b))<=0,continue,end
    cc=p90(abs(i(a:b)));tail=(a:b)';tail=tail(time(tail)>=time(b)-0.1*(time(b)-time(a)));
    if std(v(tail))<0.002&&mean(abs(i(tail)))<0.5*cc&&abs(i(b))<=0.2*cc,full=[a,b];break,end
end
if isempty(full)
    s.Message="SOC 자동 계산 불가: 완전 충전(CC-CV) 구간을 찾지 못했습니다. 시작 SOC와 용량을 직접 입력해 주세요.";return
end
for k=1:numel(st)
    a=st(k);b=en(k);if b>=full(1),break,end
    if b-a>=50&&time(b)-time(a)>=600&&median(i(a:b))<0&&v(b)<=vmin+0.05,empty=[a,b];end
end
ia=i;ia(~act)=0;q=[0;cumsum((ia(2:end)+ia(1:end-1))/2.*diff(time))]/3600;   % Ah, charge positive
if ~isempty(empty)
    s.Capacity_Ah=q(full(2))-q(empty(2));s.CapacitySource="같은 기록의 완전 방전 끝→완전 충전 끝 충전량";s.EmptyAnchor_s=time(empty(2));
elseif isfinite(o.Capacity_Ah)&&o.Capacity_Ah>0
    s.Capacity_Ah=o.Capacity_Ah;s.CapacitySource="사용자 입력 용량";
else
    s.Message="SOC 자동 계산 불가: 완전 충전은 찾았지만 용량을 정할 완전 방전 구간이 없습니다. 사용 가능 용량[Ah]을 입력해 주세요.";return
end
s.FullAnchor_s=time(full(2));
s.SOC=100+100*(q-q(full(2)))/s.Capacity_Ah;s.Found=true;
% closure check: a discharge step after the anchor that ends near the lowest voltage should bring SOC back to ~0 %
last=find(en>full(2)&arrayfun(@(k)median(i(st(k):en(k)))<0&&v(en(k))<=vmin+0.05,(1:numel(st))'),1,'last');
if ~isempty(last),s.ClosureSOC_pct=s.SOC(en(last));end
s.Message="SOC 자동 계산: 완전 충전 끝(t="+sprintf('%.0f',s.FullAnchor_s)+" s, "+sprintf('%.3f',v(full(2)))+" V)=100 %, 용량 "+ ...
    sprintf('%.3f',s.Capacity_Ah)+" Ah("+s.CapacitySource+"), 효율 1·휴지 전류 0으로 적산.";
if isfinite(s.ClosureSOC_pct),s.Message=s.Message+" 검산: 마지막 완전 방전 끝 SOC "+sprintf('%.2f',s.ClosureSOC_pct)+" %(0 %에 가까울수록 일관).";end
end
function y=p90(x)
x=sort(x(:));y=x(max(1,ceil(0.9*numel(x))));
end
