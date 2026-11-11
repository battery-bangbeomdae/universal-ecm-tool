classdef VariableImportView < handle
    properties
        UIFigure
    end
    properties (Access=private)
        VM
        Source
        Data
        Revision
        Context = struct()
        ColumnChecks = {}
        KeyChecks = {}
        StatusLabel
    end
    methods
        function app=VariableImportView(vm,M,source,info,context)
            if nargin<4||isempty(info),info=uecm.variableColumnInfo(M);end
            if nargin<5,context=struct();end
            app.Context=context;previewData=M;total=height(M);description="CSV의 열 제목을 선택하세요.";
            if isfield(context,'Preview'),previewData=context.Preview;total=context.TotalRows;description=context.Description;end
            app.VM=vm;app.Data=M;app.Source=string(source);app.Revision=vm.Revision;
            app.UIFigure=uifigure('Name','변수 추가하기 · 열 선택','Tag','VariableImportWindow','Position',[80,80,1150,720], ...
                'CloseRequestFcn',@(~,~)delete(app));
            g=uigridlayout(app.UIFigure,[5,1]);g.RowHeight={55,85,'1x',65,38};
            uilabel(g,'Text',description+" · 전체 "+total+"행 중 처음 "+min(200,total)+"행 표시. 열 제목 옆 체크박스를 선택하고 ‘선택한 변수 추가’를 누르세요.",'WordWrap','on','Tooltip',string(source));
            names=string(previewData.Properties.VariableNames);
            allowed=["fit_id","measurement_id","source_id","source_file","cell_id","test_id","spectrum_id"];
            keys=allowed(ismember(allowed,names)&ismember(allowed,string(vm.Bundle.Results.Properties.VariableNames)));
            locked=isfield(context,'JoinKeys');if locked,keys=context.JoinKeys;end
            panel=uipanel(g,'Title','연결 키 · 측정을 식별하는 열 (변수로 추가하지 않음)');
            kg=uigridlayout(panel,[1,max(1,numel(keys))]);kg.ColumnWidth=repmat({145},1,max(1,numel(keys)));kg.Scrollable='on';
            defaults=keys;
            if numel(keys)>1&&ismember("source_file",keys),defaults=keys(keys~="source_file");end
            for k=1:numel(keys)
                app.KeyChecks{k}=uicheckbox(kg,'Text',keys(k),'Tag','VariableJoinKey','UserData',keys(k),'Value',ismember(keys(k),defaults));
                if locked,app.KeyChecks{k}.Enable='off';end
            end
            preview=uigridlayout(g,[2,max(1,numel(names))+1]);preview.RowHeight={36,'1x'};preview.ColumnWidth=[repmat({175},1,max(1,numel(names))),{24}];preview.ColumnSpacing=0;preview.Padding=[0,0,0,0];preview.Scrollable='on';
            for k=1:numel(names)
                col=names(k);enabled=~ismember(col,allowed);note="식별 키: 위의 연결 키에서 선택하세요.";
                if enabled
                    j=find(info.column==col,1);enabled=~isempty(j)&&info.known_rows(j)>0;
                    if isempty(j),note="열 정보를 확인할 수 없습니다.";
                    elseif strlength(info.reason(j))>0,note=info.reason(j);
                    else
                        note=info.kind(j)+" · 값 있는 행 "+info.known_rows(j)+" / "+height(M);
                        if locked,note=info.kind(j)+" · 연결된 피팅 "+info.known_rows(j)+" / "+height(M);end
                    end
                    if ~enabled&&strlength(note)==0,note="값이 없는 열입니다.";end
                end
                c=uicheckbox(preview,'Text',col,'Tag','VariableColumnChoice','UserData',col,'Value',false,'Enable',matlab.lang.OnOffSwitchState(enabled),'Tooltip',col+" · "+note);
                c.Layout.Row=1;c.Layout.Column=k;app.ColumnChecks{k}=c;
            end
            t=uitable(preview,'Data',previewData(1:min(200,height(previewData)),:),'Tag','VariableCSVPreview','ColumnEditable',false,'RowName',{},'ColumnName',{},'ColumnWidth',repmat({175},1,numel(names)));
            t.Layout.Row=2;t.Layout.Column=[1,max(1,numel(names))+1];
            app.StatusLabel=uilabel(g,'Text','체크한 변수만 추가됩니다. 미선택 열·원본 파일·피팅값은 유지됩니다.','Tag','VariableImportStatus','WordWrap','on');
            if isempty(keys),app.StatusLabel.Text='공통 측정 키가 없습니다. 메인 화면의 키 템플릿을 저장해 fit_id 등의 식별 열을 포함하세요.';end
            controls=uigridlayout(g,[1,4]);controls.ColumnWidth={110,110,'1x',110};controls.Padding=[0,0,0,0];
            uibutton(controls,'Text','전체 선택','ButtonPushedFcn',@(~,~)app.selectAll(true));
            uibutton(controls,'Text','선택 해제','ButtonPushedFcn',@(~,~)app.selectAll(false));
            b=uibutton(controls,'Text','선택한 변수 추가','Tag','ApplySelectedVariables','ButtonPushedFcn',@(~,~)app.apply());b.Enable=matlab.lang.OnOffSwitchState(~isempty(keys));
            uibutton(controls,'Text','취소','Tag','CancelSelectedVariables','ButtonPushedFcn',@(~,~)delete(app));
        end
        function delete(app)
            if ~isempty(app.UIFigure)&&isvalid(app.UIFigure),app.UIFigure.CloseRequestFcn=[];delete(app.UIFigure);end
        end
        function setSelectedColumns(app,columns)
            columns=string(columns);
            for k=1:numel(app.ColumnChecks)
                c=app.ColumnChecks{k};c.Value=strcmp(c.Enable,'on')&&ismember(string(c.UserData),columns);
            end
        end
        function apply(app)
            try
                if app.VM.Revision~=app.Revision,error('uecm:StaleVariables','변수 선택 창을 연 뒤 결과가 변경됐습니다. 이 창을 닫고 ‘변수 추가하기’로 다시 열어 주세요.');end
                if isfield(app.Context,'SelectedFile')&&string(app.VM.SelectedFile)~=app.Context.SelectedFile
                    error('uecm:StaleVariables','선택 파일이 변경됐습니다. 이 창을 닫고 ‘변수 추가하기’를 다시 눌러 주세요.');
                end
                columns=selected(app.ColumnChecks);keys=selected(app.KeyChecks);
                app.VM.importSelectedAxes(app.Data,columns,keys,app.Source);
                if isvalid(app),delete(app);end
            catch ex
                if isvalid(app)&&isvalid(app.UIFigure),app.StatusLabel.Text=ex.message;end
            end
        end
    end
    methods (Access=private)
        function selectAll(app,value)
            for k=1:numel(app.ColumnChecks),c=app.ColumnChecks{k};c.Value=value&&strcmp(c.Enable,'on');end
        end
    end
end
function names=selected(checks)
names=strings(1,0);
for k=1:numel(checks),c=checks{k};if c.Value,names(end+1)=string(c.UserData);end,end
end
