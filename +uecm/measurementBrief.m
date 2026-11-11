function text=measurementBrief(row)
%MEASUREMENTBRIEF Two short lines; full metadata remains in the details view.
identity=strings(0,1);
for f=["fit_id","cell_id","domain","cathode_composition"]
    if ismember(f,string(row.Properties.VariableNames))
        v=string(row.(f));if ~ismissing(v)&&strlength(strtrim(v))>0
            if strlength(v)>24,v=extractBefore(v,24)+"…";end
            if f=="cell_id",v="셀 "+v;end
            identity(end+1)=v; %#ok<AGROW>
        end
    end
end
fields=["soc_pct","soh_pct","temperature_C","cycle_number"];labels=["SOC","SOH","온도","사이클"];units=["%","%","°C",""];
conditions=strings(1,4);
for k=1:4
    value="미연결";
    if ismember(fields(k),string(row.Properties.VariableNames))&&isnumeric(row.(fields(k)))&&isfinite(row.(fields(k)))
        value=compose('%.4g',row.(fields(k)))+units(k);
    end
    conditions(k)=labels(k)+" "+value;
end
text=join(identity," · ")+newline+join(conditions," · ");
end
