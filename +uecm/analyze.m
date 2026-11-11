function bundle = analyze(input, sendProgress, prepared)
%ANALYZE Diagnose then estimate independent spectra or local HPPC pulses.
arguments
    input (1,1) struct
    sendProgress (1,1) function_handle = @(~)[]
    prepared (1,1) struct = struct()
end
if isfield(input,'OriginalInputs')&&numel(input.OriginalInputs)>1
    bundle=uecm.analyzeBatch(input,sendProgress,prepared);return
end
p=uecm.analysisPrepared(input,prepared);bundle=struct('Prepared',p,'Fits',{{}},'Results',table(),'Version',"0.5.0-merged",'ComputationSchema',"uecm-v7-diffusion-1", ...
    'Timestamp',string(datetime('now','TimeZone','Asia/Seoul')),'Status',"needs_input");
bundle.CustomAxes=p.CustomAxes;bundle.AxisCategories=p.AxisCategories;
if p.Blocked,return,end
T=p.Data;o=input.Settings;
keys=T.source+char(31)+T.cell+char(31)+T.test+char(31)+T.spectrum;
if ismember('uecm_input_file',input.Data.Properties.VariableNames)
    keys=string(input.Data.uecm_input_file)+char(31)+keys;
end
[ids,~,group]=unique(keys,'stable');
count=numel(ids);rows=cell(0,1);fits=cell(0,1);
groupRows=accumarray(group,(1:height(T))',[count,1],@(indices){sort(indices)});
for k=1:count
    idx=groupRows{k};G=T(idx,:);sendProgress(struct('Index',k,'Total',count,'Message',"계산 중 "+k+" / "+count));
    try
        for field=["cell_model","cathode_family","cathode_composition","cell_format"]
            vals=G.(field); vals=unique(vals(strlength(vals)>0));
            if numel(vals)>1,error('uecm:Conditions','같은 시험에 서로 다른 셀 정보가 있습니다.');end
        end
        if p.Type=="EIS"
            for name=["soc","temperature","soh","cycle","calendar"]
                finite=G.(name)(isfinite(G.(name)));
                if numel(unique(finite))>1 && max(finite)-min(finite)>1e-6
                    error('uecm:Conditions','같은 스펙트럼에 서로 다른 조건이 섞였습니다. spectrum_id 또는 조건표 연결을 확인해 주세요.');end
            end
            parts={uecm.fitEIS(G.frequency,G.real,G.imag,o)};
            % Kramers-Kronig consistency of the measured spectrum (independent of the chosen circuit)
            try,parts{1}.KK=uecm.linKK(G.frequency,G.real,G.imag);catch kex,parts{1}.KK=struct('Status',"not_run",'MaxResidual',NaN,'Reason',string(kex.message));end
        else,parts=uecm.fitHPPC(G.time,G.current,G.voltage,o);end
        for j=1:numel(parts)
            f=parts{j};f.SourceRows=idx(f.SourceIndices);f.SourceFile=input.File;
            if ismember('uecm_input_file',input.Data.Properties.VariableNames),f.SourceFile=string(input.Data.uecm_input_file(idx(1)));end
            if p.Type=="HPPC",start=f.PulseStart;else,start=1;end
            r=emptyRow();r.source_file=f.SourceFile;r.source_id=G.source(start);r.cell_id=G.cell(start);r.test_id=G.test(start);r.spectrum_id=G.spectrum(start);
            r.fit_id="fit_"+string(numel(fits)+1);r.domain=p.Type;r.circuit=f.Circuit;r.fit_status=f.Status;r.reason=f.Reason;
            r.initial_capacity_Ah=G.initial_capacity(start);r.current_capacity_Ah=G.current_capacity(start);
            for field=["soc","soh","temperature","cycle","initial_capacity","current_capacity","calendar"]
                r.(field+"_source")=G.(field+"_source")(start);
            end
            r.soc_pct=G.soc(start);r.temperature_C=G.temperature(start);r.soh_pct=G.soh(start);r.cycle_number=G.cycle(start);r.calendar_days=G.calendar(start);
            for field=["cell_model","cathode_family","cathode_composition","cell_format"]
                vals=G.(field); vals=vals(strlength(vals)>0);
                if ~isempty(vals),r.(field)=vals(1);end
            end
            for a=p.CustomAxes
                values=G.(a.Field);v=values(start);
                if p.Type=="EIS"&&(any(~isfinite(values))||numel(unique(values(isfinite(values))))>1),v=NaN;end
                r.(a.Field)=v;
            end
            r.rmse=f.RMSE;r.error_unit=f.ErrorUnit;r.relative_error=f.RelativeError;r.solver=f.Solver;r.exit_flag=f.ExitFlag;
            r.jacobian_condition=f.Condition;r.n_fit_points=f.FitPoints;r.synthetic=input.Synthetic;r.validation="training_fit_only";
            if isfield(f,'KK'),r.kk_status=f.KK.Status;r.kk_max_residual=f.KK.MaxResidual;end
            names=fieldnames(f.Parameters);
            for z=1:numel(names),r.(names{z})=f.Parameters.(names{z});end
            r=uecm.candidateRow(r,f);f.Identity=r;
            if isfield(f,'Alternatives')
                for a=1:numel(f.Alternatives)
                    c=f.Alternatives{a};c.SourceRows=idx(c.SourceIndices);c.SourceFile=f.SourceFile;
                    c.Identity=uecm.candidateRow(r,c);f.Alternatives{a}=c;
                end
            end
            if f.Status=="review"
                action="회로·측정 대역·신호 품질을 확인해 주세요. 이 값은 주의가 필요한 임시 추정값입니다.";
                if f.Domain=="HPPC",action="펄스 전후의 더 촘촘한 기록·충분한 휴지/회복·기준전압 자료를 확인해 주세요. 이 회로 값은 임시 추정값입니다.";end
                request=table(input.File,r.fit_id,f.Reason,action,false, ...
                    'VariableNames',{'Target','Field','Reason','Action','Blocking'});
                bundle.Prepared.Requests=[bundle.Prepared.Requests;request];
            end
            fits{end+1,1}=f;rows{end+1,1}=r; %#ok<AGROW>
        end
    catch ex
        req=table(input.File,string(k),string(ex.message),"원본 측정·열 연결·회로 적합성을 확인한 뒤 다시 분석해 주세요.",true, ...
            'VariableNames',{'Target','Field','Reason','Action','Blocking'});
        bundle.Prepared.Requests=[bundle.Prepared.Requests;req];
    end
end
bundle.Fits=fits;
if ~isempty(rows),bundle.Results=struct2table(vertcat(rows{:}));bundle.Status="partial";
    if ~any(bundle.Prepared.Requests.Blocking),bundle.Status="candidate";end
end
for a=1:numel(bundle.CustomAxes)
 field=bundle.CustomAxes(a).Field;known=0;
 if ismember(field,string(bundle.Results.Properties.VariableNames)),known=nnz(isfinite(bundle.Results.(field)));end
 bundle.CustomAxes(a).LinkedCount=known;bundle.CustomAxes(a).MissingCount=height(bundle.Results)-known;
end
end
function r=emptyRow()
r=struct('source_file',"",'fit_id',"",'source_id',"",'cell_id',"",'test_id',"",'spectrum_id',"",'domain',"",'circuit',"", ...
 'cell_model',"",'cathode_family',"",'cathode_composition',"",'cell_format',"", ...
 'initial_capacity_Ah',NaN,'current_capacity_Ah',NaN, ...
 'soc_source',"",'soh_source',"",'temperature_source',"",'cycle_source',"",'initial_capacity_source',"",'current_capacity_source',"",'calendar_source',"", ...
 'model',"",'fit_status',"",'reason',"",'soc_pct',NaN,'temperature_C',NaN,'soh_pct',NaN,'cycle_number',NaN,'calendar_days',NaN, ...
 'Rs_Ohm',NaN,'Rct_Ohm',NaN,'Cdl_F',NaN,'Ceff_F',NaN,'CPE1_Q',NaN,'CPE2_Q',NaN,'CPE1_alpha',NaN,'CPE2_alpha',NaN,'Ceff1_F',NaN,'Ceff2_F',NaN,'CPE_Q',NaN,'CPE_alpha',NaN,'L_H',NaN,'Warburg_sigma_Ohm_s_mhalf',NaN, ...
 'R0_Ohm',NaN,'R1_Ohm',NaN,'C1_F',NaN,'R2_Ohm',NaN,'C2_F',NaN,'tau_s',NaN,'tau1_s',NaN,'tau2_s',NaN, ...
 'rmse',NaN,'error_unit',"",'relative_error',NaN,'solver',"",'exit_flag',NaN, ...
 'jacobian_condition',NaN,'n_fit_points',0,'synthetic',false,'validation',"training_fit_only", ...
 'kk_status',"",'kk_max_residual',NaN);   % EIS only: Lin-KK data-validity check (uecm.linKK)
end
