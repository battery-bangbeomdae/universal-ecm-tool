classdef ConditionComparisonViewModel < handle
    properties (SetObservable)
        Result = struct()
        Selected = false(0,1)
        Revision double = 0
    end
    properties (SetAccess=private)
        Data
        Domain string = "EIS"
        SourceFile string = "*"
        Model string = "*"
        CellKey string = "*"
        Direction string = "*"
        Variable string = "soc_pct"
        FitModel string = "권장 모델"
        DisplayMode string = "both"
        AllowTolerance logical = false
        Fixed = struct()
        Tolerance = struct()
    end
    methods
        function obj=ConditionComparisonViewModel(data)
            arguments
                data (1,1) struct
            end
            obj.Data=data;fields=obj.conditionFields();
            for f=fields,obj.Fixed.(f)=NaN;obj.Tolerance.(f)=0;end
            if ~isempty(data.Measurements)
                domains=unique(data.Measurements.domain,'stable');obj.Domain=domains(1);obj.resetScope();
            end
            obj.preset("soc_pct");
        end
        function fields=conditionFields(obj)
            fields=["soc_pct","temperature_C","soh_pct","cycle_number","calendar_days","pulse_amplitude_A","pulse_duration_s"];
            if isfield(obj.Data,'CustomAxes')&&~isempty(obj.Data.CustomAxes),fields=[fields,string({obj.Data.CustomAxes.Field})];end
        end
        function models=fitModelChoices(obj)
            models="권장 모델";T=obj.scopeRows();
            if ~isfield(obj.Data,'FitCandidates'),return,end
            for id=T.curve_id'
                cc=obj.Data.FitCandidates{id};for k=1:numel(cc),models(end+1)=string(cc{k}.ModelName);end
            end
            models=unique(models,'stable');
        end
        function setFitDisplay(obj,model,mode)
            if ~ismember(mode,["measured","both","fit"]),error('uecm:ComparisonDisplay','표시 모드를 확인하세요.');end
            obj.FitModel=string(model);obj.DisplayMode=string(mode);obj.Revision=obj.Revision+1;
        end
        function [fields,labels]=variableChoices(obj)
            fields=["soc_pct","temperature_C","soh_pct","cycle_number","calendar_days","cell_id"];
            labels=["SOC 변화","온도 변화","SOH 변화","사이클 변화","경과일 변화","셀 개체 비교"];
            if isfield(obj.Data,'CustomAxes')
                for a=obj.Data.CustomAxes,fields(end+1)=a.Field;labels(end+1)=obj.conditionLabel(a.Field)+" 변화";end
            end
        end
        function label=conditionLabel(obj,field)
            label=string(field);
            if isfield(obj.Data,'CustomAxes')
                for a=obj.Data.CustomAxes
                    if a.Field==field,label=a.Label;if strlength(a.Unit)>0,label=label+" ["+a.Unit+"]";end;return,end
                end
            end
        end
        function updateCustomConditions(obj,bundle)
            obj.Data=uecm.attachComparisonResults(obj.Data,bundle);
            fields=obj.conditionFields();
            for f=fields
                if ~isfield(obj.Fixed,f),obj.Fixed.(f)=NaN;obj.Tolerance.(f)=0;end
            end
            [variables,~]=obj.variableChoices();if ~ismember(obj.Variable,variables),obj.Variable="soc_pct";end
            obj.refresh();
        end
        function T=scopeRows(obj,ignoreCell)
            if nargin<2,ignoreCell=false;end
            T=obj.Data.Measurements;if isempty(T),return,end
            keep=T.domain==obj.Domain;
            if obj.SourceFile~="*",keep=keep&T.source_file==obj.SourceFile;end
            if obj.Model~="*",keep=keep&T.cell_model==obj.Model;end
            if ~ignoreCell&&obj.CellKey~="*",keep=keep&T.cell_key==obj.CellKey;end
            if obj.Direction~="*",keep=keep&(T.domain~="HPPC"|T.pulse_direction==obj.Direction);end
            T=T(keep,:);
        end
        function [values,labels]=choices(obj,field)
            T=obj.Data.Measurements;values=strings(0,1);labels=values;if isempty(T),return,end
            T=T(T.domain==obj.Domain,:);
            if field~="source_file"&&obj.SourceFile~="*",T=T(T.source_file==obj.SourceFile,:);end
            if field=="cell_key"&&obj.Model~="*",T=T(T.cell_model==obj.Model,:);end
            if isempty(T),return,end
            [values,first]=unique(T.(field),'stable');labels=values;
            if field=="source_file"
                for k=1:numel(values),[parent,name,ext]=fileparts(values(k));[~,folder]=fileparts(parent);if folder=="input",[~,folder]=fileparts(fileparts(parent));end;labels(k)=folder+" / "+name+ext;end
            elseif field=="cell_key",labels=T.cell_id(first)+" · "+T.source_id(first);
            elseif field=="cell_model",labels(strlength(values)==0)="모델 미기록";end
        end
        function setScope(obj,field,value)
            obj.(field)=string(value);
            if field=="Domain"
                obj.SourceFile="*";obj.Model="*";obj.CellKey="*";obj.resetScope();
            elseif ismember(field,["SourceFile","Model"])
                obj.CellKey="*";
                if field=="SourceFile",obj.Model="*";end
                obj.pickCell();
            end
            obj.preset(obj.Variable);
        end
        function resetScope(obj)
            if obj.Domain=="HPPC",obj.Direction="discharge";else,obj.Direction="*";end
            [models,~]=obj.choices("cell_model");known=models(strlength(models)>0);if ~isempty(known),obj.Model=known(1);end
            obj.pickCell();
        end
        function pickCell(obj)
            T=obj.scopeRows(true);
            if ~isempty(T)
                [~,first,g]=unique(T.cell_key,'stable');total=accumarray(g,1);
                complete=double(isfinite(T.soc_pct))+double(isfinite(T.temperature_C))+double(isfinite(T.soh_pct));
                coverage=accumarray(g,complete)./total;health=T.soh_pct;health(~isfinite(health))=-Inf;maximum=accumarray(g,health,[],@max);
                [~,order]=sortrows([-coverage,-maximum],[1,2]);obj.CellKey=T.cell_key(first(order(1)));
            end
        end
        function preset(obj,variable)
            obj.Variable=string(variable);
            if variable=="cell_id",obj.CellKey="*";end
            fields=obj.conditionFields();for f=fields,obj.Fixed.(f)=NaN;end
            T=obj.scopeRows();if isempty(T),obj.refresh();return,end
            if variable=="cell_id",values=T.cell_key;else,values=string(T.(variable));T=T(isfinite(T.(variable)),:);values=string(T.(variable));end
            if isempty(T),obj.refresh();return,end
            controlled=["soc_pct","temperature_C","soh_pct","pulse_amplitude_A","pulse_duration_s"];
            if ismember(variable,["cycle_number","calendar_days"]),controlled(controlled=="soh_pct")=[];end
            if ismember(variable,["soc_pct","temperature_C"])&&~any(isfinite(T.soh_pct))
                if any(isfinite(T.cycle_number)),controlled(end+1)="cycle_number";
                elseif any(isfinite(T.calendar_days)),controlled(end+1)="calendar_days";end
            end
            controlled=[controlled,fields(startsWith(fields,"custom_"))];
            key=repmat("",height(T),1);
            for f=fields
                if f==variable||~ismember(f,controlled)||(obj.Domain=="EIS"&&startsWith(f,"pulse_")),continue,end
                column=string(T.(f));column(~isfinite(T.(f)))="(unlinked)";key=key+"|"+column;
            end
            [~,~,g]=unique(key,'stable');first=accumarray(g,(1:height(T))',[],@min);
            uniquePairs=unique(table(g,values),'rows');counts=accumarray(uniquePairs.g,1,[numel(first),1]);
            distance=abs(T.temperature_C(first)-25);distance(~isfinite(distance))=Inf;
            [~,order]=sortrows([-counts,distance],[1,2]);base=first(order(1));
            for f=fields
                if f==variable||(obj.Domain=="EIS"&&startsWith(f,"pulse_")),continue,end
                vals=T.(f);v=vals(base);
                if ~ismember(f,controlled)
                    sameGroup=vals(g==g(base));finite=sameGroup(isfinite(sameGroup));
                    if isempty(finite)||any(~isfinite(sameGroup))||max(finite)-min(finite)>1e-7,v=NaN;end
                end
                if max(counts)<2&&numel(unique(values))>1
                    finite=vals(isfinite(vals));if isempty(finite)||any(~isfinite(vals))||max(finite)-min(finite)>1e-7,v=NaN;end
                end
                obj.Fixed.(f)=v;
            end
            obj.refresh();
        end
        function setConstraint(obj,field,value,tolerance,enabled)
            if ~isfinite(tolerance)||tolerance<0,error('uecm:ConditionTolerance','±허용 범위는 0 이상입니다.');end
            if enabled&&~isfinite(value),error('uecm:ConditionValue','고정 조건의 값을 입력하세요.');end
            obj.Fixed.(field)=NaN;if enabled&&field~=obj.Variable,obj.Fixed.(field)=value;end
            obj.Tolerance.(field)=tolerance;obj.refresh();
        end
        function setToleranceEnabled(obj,value)
            obj.AllowTolerance=logical(value);obj.refresh();
        end
        function refresh(obj)
            o=struct('Domain',obj.Domain,'SourceFile',obj.SourceFile,'Model',obj.Model,'CellKey',obj.CellKey,'Direction',obj.Direction, ...
                'Variable',obj.Variable,'Fixed',obj.Fixed,'Tolerance',obj.Tolerance,'AllowTolerance',obj.AllowTolerance);
            result=uecm.queryConditionComparison(obj.Data,o);obj.Result=result;obj.Selected=result.DefaultSelection;obj.Revision=obj.Revision+1;
        end
        function setSelected(obj,row,value)
            if isempty(row),obj.Selected(:)=logical(value);else,obj.Selected(row)=logical(value);end
            obj.Revision=obj.Revision+1;
        end
    end
end
