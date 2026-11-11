function data=conditionComparisonData(prepared)
%CONDITIONCOMPARISONDATA Index measured EIS/pulse traces without running a fit.
% HPPC states are sampled at pulse onset; V0 is median of up to ten preceding rest samples.
arguments
 prepared (1,1) struct
end
parts={prepared};if isfield(prepared,'FilePrepared'),parts=prepared.FilePrepared;end
rowOffsets=[0;cumsum(cellfun(@(q)height(q.Input.Data),parts(:)))];
records={};series={};issues=strings(0,1);
for k=1:numel(parts)
 p=parts{k};N=p.Data;file=string(p.Input.File);
 if p.Blocked,issues(end+1)=file+": 입력 진단이 보류되어 제외했습니다.";continue,end
 if ~ismember(p.Type,["EIS","HPPC"]),continue,end
 if isempty(N),continue,end
 groups=findgroups(N.source,N.cell,N.test,N.spectrum);valid=isfinite(groups);
 if ~all(valid),issues(end+1)=file+": ID 미연결 행을 제외했습니다.";end
 if ~any(valid),continue,end
 rows=accumarray(groups(valid),find(valid),[],@(r){r});
 for j=1:numel(rows)
  ids=rows{j};G=N(ids,:);windows={};starts=[];
  if p.Type=="EIS"
   if any(~isfinite([G.frequency;G.real;G.imag]))||any(G.frequency<=0),issues(end+1)=G.spectrum(1)+": 유효하지 않은 EIS 신호.";continue,end
   windows={1:height(G)};starts=1;
  else
   if any(~isfinite([G.time;G.current;G.voltage]))||any(diff(G.time)<=0),issues(end+1)=G.spectrum(1)+": HPPC 시간/신호를 확인하세요.";continue,end
   active=abs(G.current)>max(.02*max(abs(G.current)),1e-8);
   first=find(diff([false;active])==1);last=find(diff([active;false])==-1);
   for h=1:numel(first)
    previous=0;if h>1,previous=last(h-1);end
    after=height(G);if h<numel(first),after=first(h+1)-1;end
    before=(previous+1):(first(h)-1);amp=median(G.current(first(h):last(h)));
    % Same coverage/constant-current safeguards as fitHPPC, but no solver is called.
    if numel(before)<5||last(h)-first(h)<5||after-last(h)<5||std(G.current(first(h):last(h)))>.05*abs(amp),continue,end
    windows{end+1}=before(max(1,end-9)):after;starts(end+1)=first(h); %#ok<AGROW>
   end
   if isempty(windows),issues(end+1)=G.spectrum(1)+": 휴지·일정 전류 펄스·회복 구간이 확인되지 않았습니다.";end
  end
  for h=1:numel(windows)
   idx=windows{h};onset=starts(h);r=struct('curve_id',numel(records)+1,'domain',p.Type,'source_file',file,'source_id',G.source(onset), ...
    'synthetic',logical(p.Input.Synthetic),'cell_model',G.cell_model(onset),'cell_id',G.cell(onset),'cell_key',file+char(31)+G.source(onset)+char(31)+G.cell(onset), ...
    'test_id',G.test(onset),'onset_source_row',ids(onset)+rowOffsets(k),'onset_file_row',ids(onset),'measurement_id',G.spectrum(onset),'pulse_number',h,'points',numel(idx), ...
    'pulse_amplitude_A',NaN,'pulse_duration_s',NaN,'pulse_direction',"",'temperature_min_C',NaN,'temperature_max_C',NaN,'condition_note',"");
   internal=["soc","soh","temperature","cycle","calendar","initial_capacity","current_capacity"];
   external=["soc_pct","soh_pct","temperature_C","cycle_number","calendar_days","initial_capacity_Ah","current_capacity_Ah"];
   for f=1:numel(internal)
    values=G.(internal(f))(idx);finite=values(isfinite(values));v=G.(internal(f))(onset);
    if p.Type=="EIS"&&(any(~isfinite(values))||(~isempty(finite)&&max(finite)-min(finite)>1e-6))
     v=NaN;r.condition_note=r.condition_note+external(f)+" 구간 내 변동/결측; ";
    end
    r.(external(f))=v;
   end
   if isfield(p,'CustomAxes')
    for a=p.CustomAxes
     v=G.(a.Field)(onset);values=G.(a.Field)(idx);
     if p.Type=="EIS"&&(any(~isfinite(values))||numel(unique(values(isfinite(values))))>1),v=NaN;end
     r.(a.Field)=v;
    end
   end
   t=G.temperature(idx);t=t(isfinite(t));if ~isempty(t),r.temperature_min_C=min(t);r.temperature_max_C=max(t);end
   s=struct('Domain',p.Type,'Frequency',[],'Real',[],'Imag',[],'Time',[],'Voltage',[],'DeltaVoltage',[],'Current',[],'Baseline',NaN,'SourceRows',ids(idx));
   if p.Type=="EIS"
    [s.Frequency,order]=sort(G.frequency(idx),'descend');s.Real=G.real(idx(order));s.Imag=G.imag(idx(order));s.SourceRows=ids(idx(order));
   else
    active=abs(G.current)>max(.02*max(abs(G.current)),1e-8);stop=onset;while stop<height(G)&&active(stop+1),stop=stop+1;end
    before=idx(idx<onset);base=median(G.voltage(before(max(1,end-9):end)));
    s.Time=G.time(idx)-G.time(onset);s.Voltage=G.voltage(idx);s.DeltaVoltage=G.voltage(idx)-base;s.Current=G.current(idx);s.Baseline=base;
    amp=median(G.current(onset:stop));r.pulse_amplitude_A=abs(amp);r.pulse_duration_s=G.time(stop)-G.time(onset);
    r.pulse_direction="discharge";if amp<0,r.pulse_direction="charge";end
    r.condition_note=r.condition_note+"조건은 펄스 시작 값; 전류는 방전 +; ΔV=V−펄스 직전 휴지 중앙값.";
   end
   s.SourceRows=s.SourceRows+rowOffsets(k);
   records{end+1,1}=r;series{end+1,1}=s; %#ok<AGROW>
  end
 end
end
T=table();if ~isempty(records),T=struct2table(vertcat(records{:}));end
data=struct('Measurements',T,'Series',{series},'Issues',unique(issues,'stable'),'FittingExecuted',false);
if isfield(prepared,'CustomAxes'),data.CustomAxes=prepared.CustomAxes;data.ImportedAxes=prepared.CustomAxes;data.AxisCategories=prepared.AxisCategories;end
end
