function s = screenTimeSeries(time, current, voltage, settings)
%SCREENTIMESERIES Time-order screening of one HPPC test group BEFORE fitting. Never sorts, never edits values.
%  1) exact duplicate rows (same time, current, voltage)      -> dropped (lossless), counted
%  2) same time, different values (logger step transitions)  -> settings.DuplicateTimePolicy
%        "block" (default): request a decision     "keep_last": keep the last row of each timestamp
%  3) time going backwards (re-logged copy appended, counter reset) -> settings.TimeResetPolicy
%        "block" (default)   "keep_first_log": keep the first log; from later logs only rows after its end
%  Found in the Samsung 30T (McMaster/Digatron) archive: ~0.6 % duplicate timestamps in every file
%  (89-90 % of them exact duplicates) and two 40 degC files with a sparser re-log appended (722_Mixed3/4).
% Output: Keep (logical), Blocking (logical), Message (string), Counts (struct)
arguments
    time (:,1) double
    current (:,1) double
    voltage (:,1) double
    settings (1,1) struct = uecm.defaults()
end
o=settings; n=numel(time); keep=true(n,1); msg=strings(0,1); blocking=false;
counts=struct('exact_duplicates',0,'same_time_different_values',0,'time_resets',0,'reset_rows_dropped',0);
if n==0,s=pack();return,end
if any(~isfinite([time;current;voltage]))
    blocking=true;msg(end+1)="시간·전류·전압에 결측/비유한 값이 있습니다. 원본을 확인해 주세요.";s=pack();return
end
% 3) resets first: they create overlapping time ranges
d=diff(time); resets=find(d<0);
if ~isempty(resets)
    counts.time_resets=numel(resets);
    if o.TimeResetPolicy=="keep_first_log"
        b=[0;resets;n]; tmax=-Inf; k2=false(n,1);
        for j=1:numel(b)-1
            seg=(b(j)+1:b(j+1))'; take=seg(time(seg)>tmax); k2(take)=true; tmax=max(tmax,max(time(seg)));
        end
        counts.reset_rows_dropped=sum(~k2); keep=keep&k2;
        msg(end+1)="시간 되돌아감 "+numel(resets)+"회: 첫 기록을 쓰고 이후 기록은 그 끝 이후 행만 사용("+counts.reset_rows_dropped+"행 제외).";
    else
        blocking=true;
        msg(end+1)="시간 역전 "+numel(resets)+"회(시간이 되돌아감 — 같은 시험이 다시 기록됐을 수 있음). 자동 정렬하지 않습니다. "+ ...
            "원본을 확인하거나 '시간 되돌아감 처리'를 keep_first_log로 선택해 주세요.";
    end
end
% 1)+2) duplicates among kept rows
idx=find(keep); t=time(idx); i=current(idx); v=voltage(idx);
same=[diff(t)==0;false];                       % row j has the same time as row j+1
exact=same & [abs(diff(i))==0 & abs(diff(v))==0;false];
counts.exact_duplicates=sum(exact);
keep(idx(exact))=false;                        % drop the first of each identical pair (lossless)
idx=find(keep); t=time(idx); i=current(idx); v=voltage(idx);
same=[diff(t)==0;false]; counts.same_time_different_values=sum(same);
if counts.exact_duplicates>0,msg(end+1)="완전히 같은 중복 행 "+counts.exact_duplicates+"개 제외(값 손실 없음).";end
if counts.same_time_different_values>0
    if o.DuplicateTimePolicy=="keep_last"
        keep(idx(same))=false;
        msg(end+1)="같은 시각·다른 값 "+counts.same_time_different_values+"개: 각 시각의 마지막 행 사용(설정 keep_last).";
    else
        blocking=true;
        msg(end+1)="시간 역전/중복: 같은 시각에 다른 값이 "+counts.same_time_different_values+"개 있습니다. 자동 정렬하지 않습니다. "+ ...
            "시험기 단계 전환 기록이면 '같은 시각 중복 처리'를 keep_last로 선택해 주세요.";
    end
end
s=pack();
    function s=pack()
        if isempty(msg),m="시간 순서 이상 없음.";else,m=join(msg," ");end
        s=struct('Keep',keep,'Blocking',blocking,'Message',m,'Counts',counts);
    end
end
