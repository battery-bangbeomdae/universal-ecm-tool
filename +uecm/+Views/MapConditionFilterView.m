classdef MapConditionFilterView < handle
    properties
        UIFigure
    end
    properties (Access=private)
        VM
        AxisFields
        Fields = strings(1,0)
        GridTable
        Selectors = struct()
    end
    methods
        function app=MapConditionFilterView(vm,x,y)
            arguments
                vm uecm.ViewModels.MainViewModel
                x (1,1) string
                y (1,1) string
            end
            app.VM=vm;app.AxisFields=[x,y];
            [app.Fields,~]=vm.axisChoices();
            app.createUI();
        end
        function delete(app)
            if ~isempty(app.UIFigure)&&isvalid(app.UIFigure),delete(app.UIFigure);end
        end
    end
    methods (Access=private)
        function createUI(app)
            R=app.VM.Bundle.Results;
            if ismember('source_file',R.Properties.VariableNames)&&strlength(app.VM.SelectedFile)>0,R=R(string(R.source_file)==app.VM.SelectedFile,:);end
            app.UIFigure=uifigure('Name','3D 맵 · 나머지 조건 한정','Tag','MapConditionFilterFigure','CloseRequestFcn',@(~,~)delete(app));app.UIFigure.Position(3:4)=[900,640];
            g=uigridlayout(app.UIFigure,[6,1]);g.RowHeight={64,70,35,'1x',38,36};
            uilabel(g,'Text',"X="+app.AxisFields(1)+", Y="+app.AxisFields(2)+". 이 두 축을 제외한 조건만 한정합니다. 범위를 켠 필드의 미연결 값은 제외하고, 같은 좌표의 점을 평균내지 않습니다.",'WordWrap','on','FontSize',13);
            selectors=uigridlayout(g,[2,4]);selectors.RowHeight={22,34};selectors.Padding=[0,0,0,0];names=["출처","셀 모델","셀 개체","EIS/HPPC"];fields=["source_id","cell_model","cell_id","domain"];
            for k=1:numel(fields)
                f=fields(k);l=uilabel(selectors,'Text',names(k));l.Layout.Row=1;l.Layout.Column=k;values=strings(0,1);
                if ismember(f,string(R.Properties.VariableNames)),values=unique(string(R.(f)),'stable');values=values(~ismissing(values)&strlength(values)>0);end
                dd=uidropdown(selectors,'Items',cellstr(["전체";values]),'ItemsData',cellstr(["*";values]),'Tag',"MapFilter_"+f);dd.Layout.Row=2;dd.Layout.Column=k;
                if isfield(app.VM.MapFilters,f)&&ismember(string(app.VM.MapFilters.(f)),["*";values]),dd.Value=char(app.VM.MapFilters.(f));end
                app.Selectors.(f)=dd;
            end
            uilabel(g,'Text','고정값: 최소=최대 / 범위: 최소≤값≤최대. 축으로 선택한 행의 제한은 적용하지 않습니다.','WordWrap','on');
            enabled=false(numel(app.Fields),1);lo=nan(numel(app.Fields),1);hi=lo;
            [~,axisLabels]=app.VM.axisChoices();labels=axisLabels(:);
            for k=1:numel(app.Fields)
                f=app.Fields(k);
                if ismember(f,string(R.Properties.VariableNames)),v=R.(f);v=v(isfinite(v));if ~isempty(v),lo(k)=min(v);hi(k)=max(v);end,end
                if isfield(app.VM.MapFilters,'Numeric')
                    C=app.VM.MapFilters.Numeric;j=find(string(C.field)==f,1);if ~isempty(j),enabled(k)=C.enabled(j);lo(k)=C.minimum(j);hi(k)=C.maximum(j);end
                end
                if ismember(f,app.AxisFields),enabled(k)=false;labels(k)=labels(k)+" (축: 한정 제외)";end
            end
            app.GridTable=uitable(g,'Tag','MapConditionRanges','Data',table(labels,enabled,lo,hi,'VariableNames',{'condition','enabled','minimum','maximum'}), ...
                'ColumnName',{'조건','사용','최소','최대'},'ColumnEditable',[false,true,true,true],'ColumnWidth',{250,60,'auto','auto'}, ...
                'CellEditCallback',@(~,~)app.preventAxisConstraint());
            controls=uigridlayout(g,[1,3]);controls.Padding=[0,0,0,0];uibutton(controls,'Text','선택 초기화','ButtonPushedFcn',@(~,~)app.reset());uibutton(controls,'Text','적용','Tag','MapFilterApply','ButtonPushedFcn',@(~,~)app.apply());uibutton(controls,'Text','닫기','ButtonPushedFcn',@(~,~)delete(app));
            uilabel(g,'Text','조건 한정은 표시만 바꿉니다. 피팅 결과·입력 조건표는 수정하지 않습니다.','WordWrap','on');
        end
        function preventAxisConstraint(app)
            T=app.GridTable.Data;T.enabled(ismember(app.Fields,app.AxisFields))=false;app.GridTable.Data=T;
        end
        function reset(app)
            T=app.GridTable.Data;T.enabled(:)=false;app.GridTable.Data=T;
            for f=string(fieldnames(app.Selectors))',app.Selectors.(f).Value='*';end
        end
        function apply(app)
            T=app.GridTable.Data;T.enabled(ismember(app.Fields,app.AxisFields))=false;
            filters=struct('Numeric',table(app.Fields',T.enabled,T.minimum,T.maximum,'VariableNames',{'field','enabled','minimum','maximum'}));
            for f=string(fieldnames(app.Selectors))',filters.(f)=string(app.Selectors.(f).Value);end
            try,app.VM.setMapFilters(filters);catch ex,uialert(app.UIFigure,ex.message,'조건 범위 확인');return,end
        end
    end
end
