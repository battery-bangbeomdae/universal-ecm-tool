classdef ConditionComparisonView < handle
    % Measured curves and saved fitted responses. Never launches a solver.
    properties
        UIFigure
        VM
    end
    properties (Access=private)
        Listeners = event.proplistener.empty
        DomainDD
        SourceDD
        ModelDD
        CellDD
        VariableDD
        ConstraintTable
        CurveTable
        Summary
        ApproxCheck
        DirectionDD
        ResponseDD
        ModeDD
        FitDD
        DisplayDD
        FitNote
        FrequencyDD
        FMin
        FMax
        InductiveCheck
        PlotGrid
        PageLabel
        Page = 1
        LastIDs = []
        Syncing = false
        RootGrid
    end
    methods
        function app=ConditionComparisonView(vm)
            arguments
                vm uecm.ViewModels.ConditionComparisonViewModel
            end
            app.VM=vm;app.createUI();app.Listeners=addlistener(vm,'Revision','PostSet',@(~,~)app.refresh());app.refresh();app.UIFigure.Visible='on';
        end
        function delete(app)
            delete(app.Listeners);if ~isempty(app.UIFigure)&&isvalid(app.UIFigure),delete(app.UIFigure);end
        end
        function choosePreset(app,variable)
            app.VM.preset(string(variable));
        end
    end
    methods (Access=private)
        function createUI(app)
            app.UIFigure=uifigure('Name','조건별 EIS · HPPC 실측 비교','AutoResizeChildren','off','Visible','off','Position',[60,50,1450,950],'Tag','ConditionComparisonFigure','CloseRequestFcn',@(src,~)set(src,'Visible','off'));
            root=uigridlayout(app.UIFigure,[5,2]);root.RowHeight={92,80,'1x',38,28};root.ColumnWidth={370,1040};root.Scrollable='on';app.RootGrid=root;app.UIFigure.SizeChangedFcn=@(~,~)app.resizeLayout();
            root.Padding=[16,12,16,12];
            scope=uigridlayout(root,[2,5]);scope.Layout.Column=[1,2];scope.RowHeight={22,36};scope.ColumnWidth={100,'1x','1x','1.2x',180};scope.Padding=[0,0,0,0];
            names=["측정 종류","파일/연구","셀 모델","셀 개체 (출처 구분)","변화시킬 조건"];
            for j=1:5,l=uilabel(scope,'Text',names(j));l.Layout.Row=1;l.Layout.Column=j;end
            app.DomainDD=uidropdown(scope,'Items',{'EIS','HPPC'},'Tag','ConditionDomain','ValueChangedFcn',@(s,~)app.scopeChanged('Domain',s.Value));app.DomainDD.Layout.Row=2;app.DomainDD.Layout.Column=1;
            app.SourceDD=uidropdown(scope,'Items',{'전체'},'Tag','ConditionSource','ValueChangedFcn',@(s,~)app.scopeChanged('SourceFile',s.Value));app.SourceDD.Layout.Row=2;app.SourceDD.Layout.Column=2;
            app.ModelDD=uidropdown(scope,'Items',{'전체'},'Tag','ConditionModel','ValueChangedFcn',@(s,~)app.scopeChanged('Model',s.Value));app.ModelDD.Layout.Row=2;app.ModelDD.Layout.Column=3;
            app.CellDD=uidropdown(scope,'Items',{'전체'},'Tag','ConditionCell','ValueChangedFcn',@(s,~)app.scopeChanged('CellKey',s.Value));app.CellDD.Layout.Row=2;app.CellDD.Layout.Column=4;
            app.VariableDD=uidropdown(scope,'Items',{'SOC 변화','온도 변화','SOH 변화','사이클 변화','경과일 변화','셀 개체 비교'},'ItemsData',{'soc_pct','temperature_C','soh_pct','cycle_number','calendar_days','cell_id'},'Tag','ConditionVariable','ValueChangedFcn',@(s,~)app.VM.preset(string(s.Value)));app.VariableDD.Layout.Row=2;app.VariableDD.Layout.Column=5;
            app.Summary=uilabel(root,'Text','','WordWrap','on','FontSize',13,'Tag','ConditionComparisonSummary');app.Summary.Layout.Row=2;app.Summary.Layout.Column=[1,2];
            left=uigridlayout(root,[8,1]);left.Layout.Row=3;left.Layout.Column=1;left.RowHeight={34,226,30,34,60,'1x',32,28};left.Padding=[0,0,0,0];left.Scrollable='on';
            uibutton(left,'Text','현재 자료에서 대표 고정 조건 찾기','Tag','ConditionAutoPreset','ButtonPushedFcn',@(~,~)app.VM.preset(app.VM.Variable));
            app.ConstraintTable=uitable(left,'Tag','ConditionConstraints','ColumnName',{'고정 조건','사용','값','±허용'},'ColumnEditable',[false,true,true,true], ...
                'ColumnWidth',{115,45,85,85},'CellEditCallback',@(~,e)app.constraintChanged(e));
            app.ApproxCheck=uicheckbox(left,'Text','직접 지정한 ±허용 범위 사용','Tag','ConditionAllowTolerance','Value',false,'ValueChangedFcn',@(s,~)app.VM.setToleranceEnabled(s.Value));
            hp=uigridlayout(left,[1,2]);hp.Padding=[0,0,0,0];
            app.DirectionDD=uidropdown(hp,'Items',{'HPPC 방전','HPPC 충전','전류 방향 전체'},'ItemsData',{'discharge','charge','*'},'Tag','ConditionPulseDirection','ValueChangedFcn',@(s,~)app.scopeChanged('Direction',s.Value));
            app.ResponseDD=uidropdown(hp,'Items',{'ΔV [mV]','전압 [V]'},'ItemsData',{'delta','voltage'},'Tag','ConditionPulseResponse','ValueChangedFcn',@(~,~)app.render());
            uilabel(left,'Text','미기록 조건은 고정했다고 간주하지 않습니다. HPPC 조건은 펄스 시작 값이며 전류·지속시간도 확인하세요.','WordWrap','on');
            app.CurveTable=uitable(left,'Tag','ConditionCurves','CellEditCallback',@(~,e)app.curveChanged(e));
            select=uigridlayout(left,[1,2]);select.Padding=[0,0,0,0];uibutton(select,'Text','전체 선택','ButtonPushedFcn',@(~,~)app.VM.setSelected([],true));uibutton(select,'Text','선택 해제','ButtonPushedFcn',@(~,~)app.VM.setSelected([],false));
            uilabel(left,'Text','선택이 많으면 8개씩 표시합니다. 다음 페이지로 모두 볼 수 있습니다.','WordWrap','on','FontSize',10);
            right=uigridlayout(root,[2,1]);right.Layout.Row=3;right.Layout.Column=2;right.RowHeight={76,'1x'};right.Padding=[0,0,0,0];
            options=uigridlayout(right,[2,6]);options.RowHeight={32,32};options.ColumnWidth={125,135,85,85,140,'1x'};options.Padding=[0,0,0,0];
            app.ModeDD=uidropdown(options,'Items',{'겹쳐 보기','세로 분할'},'ItemsData',{'overlay','split'},'Tag','ConditionPlotMode','ValueChangedFcn',@(~,~)app.render());
            app.FrequencyDD=uidropdown(options,'Items',{'전체 주파수','1–1000 Hz','직접 범위'},'ItemsData',{'all','band','custom'},'Tag','ConditionFrequency','ValueChangedFcn',@(~,~)app.frequencyChanged());
            app.FMin=uieditfield(options,'numeric','Value',1,'Limits',[0,Inf],'Tag','ConditionFMin','Enable','off','Tooltip','최소 주파수 [Hz]','ValueChangedFcn',@(~,~)app.render());
            app.FMax=uieditfield(options,'numeric','Value',1000,'Limits',[0,Inf],'Tag','ConditionFMax','Enable','off','Tooltip','최대 주파수 [Hz]','ValueChangedFcn',@(~,~)app.render());
            app.InductiveCheck=uicheckbox(options,'Text','유도성 영역 포함','Value',true,'Tag','ConditionInductive','ValueChangedFcn',@(~,~)app.render());
            uibutton(options,'Text','현재 그림 저장','ButtonPushedFcn',@(~,~)app.exportPlots());
            app.FitDD=uidropdown(options,'Items',{'권장 모델'},'Tag','ConditionFitModel','ValueChangedFcn',@(~,~)app.fitDisplayChanged());app.FitDD.Layout.Row=2;app.FitDD.Layout.Column=[1,2];
            app.DisplayDD=uidropdown(options,'Items',{'실측만','실측 + 피팅','피팅만'},'ItemsData',{'measured','both','fit'},'Value','both','Tag','ConditionFitDisplay','ValueChangedFcn',@(~,~)app.fitDisplayChanged());app.DisplayDD.Layout.Row=2;app.DisplayDD.Layout.Column=[3,4];
            app.FitNote=uilabel(options,'Text','','WordWrap','on','Tag','ConditionFitNote');app.FitNote.Layout.Row=2;app.FitNote.Layout.Column=[5,6];
            app.PlotGrid=uigridlayout(right,[1,1]);app.PlotGrid.Scrollable='on';app.PlotGrid.RowHeight={520};app.PlotGrid.Tag='ConditionPlotGrid';
            nav=uigridlayout(root,[1,3]);nav.Layout.Row=4;nav.Layout.Column=[1,2];nav.ColumnWidth={95,'1x',95};nav.Padding=[0,0,0,0];uibutton(nav,'Text','이전','ButtonPushedFcn',@(~,~)app.movePage(-1));app.PageLabel=uilabel(nav,'Text','','HorizontalAlignment','center','Tag','ConditionPage');uibutton(nav,'Text','다음','ButtonPushedFcn',@(~,~)app.movePage(1));
            tip=uilabel(root,'Text','저장된 피팅만 표시 · 재피팅 없음 · 범례 클릭: 곡선 숨김/표시 · 점 선택: 주파수/시간/측정 ID · 분할 그래프는 스크롤','WordWrap','on');tip.Layout.Row=5;tip.Layout.Column=[1,2];
        end
        function resizeLayout(app)
            if ~isempty(app.RootGrid)&&isvalid(app.RootGrid)
                width=app.UIFigure.Position(3);app.RootGrid.ColumnWidth={370,max(760,width-420)};
            end
        end
        function fitDisplayChanged(app)
            if ~app.Syncing,app.VM.setFitDisplay(string(app.FitDD.Value),string(app.DisplayDD.Value));end
        end
        function scopeChanged(app,field,value)
            if ~app.Syncing,app.VM.setScope(field,value);end
        end
        function setChoices(~,dd,values,labels,current)
            dd.Items=cellstr(["전체";labels]);dd.ItemsData=cellstr(["*";values]);
            if ismember(current,["*";values]),dd.Value=char(current);else,dd.Value='*';end
        end
        function refresh(app)
            app.resizeLayout();app.Syncing=true;vm=app.VM;app.DomainDD.Value=char(vm.Domain);
            models=unique([vm.fitModelChoices(),vm.FitModel],'stable');old=vm.FitModel;
            app.FitDD.Items=cellstr(models);app.FitDD.Value=char(old);app.DisplayDD.Value=char(vm.DisplayMode);
            [variables,variableLabels]=vm.variableChoices();app.VariableDD.ItemsData={};app.VariableDD.Items=cellstr(variableLabels);app.VariableDD.ItemsData=cellstr(variables);app.VariableDD.Value=char(vm.Variable);
            [v,l]=vm.choices("source_file");app.setChoices(app.SourceDD,v,l,vm.SourceFile);
            [v,l]=vm.choices("cell_model");app.setChoices(app.ModelDD,v,l,vm.Model);
            [v,l]=vm.choices("cell_key");app.setChoices(app.CellDD,v,l,vm.CellKey);
            app.ApproxCheck.Value=vm.AllowTolerance;app.DirectionDD.Value=char(vm.Direction);
            app.DirectionDD.Enable=matlab.lang.OnOffSwitchState(vm.Domain=="HPPC");app.ResponseDD.Enable=app.DirectionDD.Enable;
            fields=vm.conditionFields();fixed=nan(numel(fields),1);tol=zeros(numel(fields),1);use=false(numel(fields),1);labels=strings(numel(fields),1);
            for k=1:numel(fields),f=fields(k);fixed(k)=vm.Fixed.(f);tol(k)=vm.Tolerance.(f);use(k)=isfinite(fixed(k));labels(k)=app.label(f);if f==vm.Variable,labels(k)=labels(k)+" (변화축)";end,end
            app.ConstraintTable.Data=table(labels,use,fixed,tol,'VariableNames',{'condition','enabled','value','tolerance'});
            T=vm.Result.Table;ids=[];if ~isempty(T),ids=T.curve_id;end
            if ~isequal(ids,app.LastIDs),app.Page=1;app.LastIDs=ids;end
            if isempty(T),app.CurveTable.Data=table();
            else
                fields=["cell_id","soc_pct","temperature_C","soh_pct","cycle_number","calendar_days","pulse_amplitude_A","pulse_duration_s","temperature_min_C","temperature_max_C","measurement_id","source_id","cell_model"];
                extra=vm.conditionFields();extra=extra(startsWith(extra,"custom_"));fields=[fields,extra];
                fields=[vm.Variable,fields(fields~=vm.Variable)];
                visible=T(:,cellstr(fields));if isfield(vm.Data,'AxisCategories'),for a=vm.Data.AxisCategories,if ismember(a.Field,string(visible.Properties.VariableNames)),visible.(a.Field)=uecm.axisValueLabel(vm.Data,a.Field,visible.(a.Field));end;end;end
                visible=addvars(visible,vm.Selected,'Before',1,'NewVariableNames','selected');app.CurveTable.Data=visible;app.CurveTable.ColumnEditable=[true,false(1,numel(fields))];app.CurveTable.ColumnName=[{'표시'},cellstr(arrayfun(@(f)app.label(f),fields))];
                widths=repmat({80},1,numel(fields));widths(fields=="cell_id")={120};widths(fields=="measurement_id")={190};widths(fields=="cell_model")={150};app.CurveTable.ColumnWidth=[{45},widths];
            end
            domainText="Nyquist · 실제 EIS";if vm.Domain=="HPPC",domainText="HPPC 실측 응답 · 펄스 시작 t=0, 방전 전류 +";end
            if ~isempty(T)&&any(T.synthetic),domainText="가상 연습 자료 포함 · 실측으로 해석하지 마세요 | "+domainText;end
            app.Summary.Text=char(domainText+" | "+app.label(vm.Variable)+" 비교. "+app.pretty(vm.Result.Message));
            if ~isempty(vm.Data.Issues)
                first=vm.Data.Issues(1);if strlength(first)>220,first=extractBefore(first,220)+"…";end
                app.Summary.Text=char(string(app.Summary.Text)+" 입력 검토 "+numel(vm.Data.Issues)+"건: "+first);
            end
            app.Syncing=false;app.render();
        end
        function constraintChanged(app,event)
            row=event.Indices(1);fields=app.VM.conditionFields();D=app.ConstraintTable.Data;
            try,app.VM.setConstraint(fields(row),D.value(row),D.tolerance(row),D.enabled(row));
            catch ex,uialert(app.UIFigure,ex.message,'조건 확인');app.refresh();end
        end
        function curveChanged(app,event)
            if event.Indices(2)==1,app.VM.setSelected(event.Indices(1),logical(event.NewData));end
        end
        function frequencyChanged(app)
            custom=string(app.FrequencyDD.Value)=="custom";app.FMin.Enable=matlab.lang.OnOffSwitchState(custom);app.FMax.Enable=app.FMin.Enable;app.render();
        end
        function movePage(app,step)
            pages=max(1,ceil(nnz(app.VM.Selected)/8));app.Page=min(pages,max(1,app.Page+step));app.render();
        end
        function render(app)
            delete(app.PlotGrid.Children);T=app.VM.Result.Table;selected=find(app.VM.Selected);total=numel(selected);
            pages=max(1,ceil(total/8));app.Page=min(pages,max(1,app.Page));chosen=selected((app.Page-1)*8+1:min(app.Page*8,total));
            app.PageLabel.Text=sprintf('선택 %d개 · %d / %d 페이지 · 각 페이지 최대 8개',total,app.Page,pages);
            if isempty(chosen),app.FitNote.Text='선택한 측정이 없습니다.';app.PlotGrid.RowHeight={480};ax=uiaxes(app.PlotGrid);title(ax,'조건을 확인하고 표에서 곡선을 선택하세요.');return,end
            split=string(app.ModeDD.Value)=="split";cards=1;if split,cards=numel(chosen);end
            isPulse=app.VM.Domain=="HPPC";height=520;if isPulse,height=650;end
            app.PlotGrid.RowHeight=repmat({height},1,cards);app.PlotGrid.ColumnWidth={'1x'};
            colors=lines(8);fitCount=0;reviewCount=0;
            for row=chosen'
                c=uecm.comparisonCandidate(app.VM.Data,T.curve_id(row),string(app.FitDD.Value));
                if ~isempty(c),fitCount=fitCount+1;if isfield(c,'Status')&&c.Status=="review",reviewCount=reviewCount+1;end,end
            end
            app.FitNote.Text=sprintf('현재 페이지 피팅 %d/%d · 모델 없음 %d · 주의 %d',fitCount,numel(chosen),numel(chosen)-fitCount,reviewCount);
            for card=1:cards
                indices=chosen;if split,indices=chosen(card);end
                panel=uipanel(app.PlotGrid);panel.Layout.Row=card;cardGrid=uigridlayout(panel,[1+isPulse,1]);cardGrid.RowHeight={ '1x' };if isPulse,cardGrid.RowHeight={'2x','1x'};end
                ax=uiaxes(cardGrid,'Tag','ConditionResponseAxes');hold(ax,'on');currentAxes=[];
                if isPulse,currentAxes=uiaxes(cardGrid,'Tag','ConditionCurrentAxes');hold(currentAxes,'on');end
                emptyCurves=0;timeLimits=[Inf,-Inf];
                for j=1:numel(indices)
                    row=indices(j);r=T(row,:);s=app.VM.Data.Series{r.curve_id};color=colors(find(chosen==row,1),:);
                    name=app.curveLabel(r);candidate=uecm.comparisonCandidate(app.VM.Data,r.curve_id,string(app.FitDD.Value));
                    showMeasured=app.VM.DisplayMode~="fit";
                    if ~isPulse
                        keep=true(size(s.Frequency));mode=string(app.FrequencyDD.Value);
                        if mode=="band",keep=keep&s.Frequency>=1&s.Frequency<=1000;
                        elseif mode=="custom",keep=keep&s.Frequency>=app.FMin.Value&s.Frequency<=app.FMax.Value;end
                        if ~app.InductiveCheck.Value,keep=keep&s.Imag<=0;end
                        if ~any(keep),emptyCurves=emptyCurves+1;continue,end
                        style='o-';if ~isempty(candidate)&&app.VM.DisplayMode=="both",style='o';end
                        h=plot(ax,s.Real(keep)*1000,-s.Imag(keep)*1000,style,'MarkerSize',3,'LineWidth',1.2,'Color',color,'DisplayName',[name ' · 실측'],'Tag','ConditionMeasuredCurve');
                        h.DataTipTemplate.DataTipRows(1).Label="Z′ [mΩ]";h.DataTipTemplate.DataTipRows(2).Label="−Z″ [mΩ]";h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('주파수 [Hz]',s.Frequency(keep));
                    else
                        timeLimits=[min(timeLimits(1),min(s.Time)),max(timeLimits(2),max(s.Time))];
                        value=s.Voltage;ylabel(ax,'전압 [V]');
                        if string(app.ResponseDD.Value)=="delta",value=s.DeltaVoltage*1000;ylabel(ax,'ΔV = V−V₀ [mV]');end
                        h=plot(ax,s.Time,value,'-','LineWidth',1.35,'Color',color,'DisplayName',[name ' · 실측'],'Tag','ConditionMeasuredCurve');
                        h.DataTipTemplate.DataTipRows(1).Label="펄스 기준 시간 [s]";h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('전류 [A] (방전 +)',s.Current);
                        plot(currentAxes,s.Time,s.Current,'-','LineWidth',1.15,'Color',color,'DisplayName',name);
                    end
                    if ~showMeasured,delete(h);else
                    n=numel(h.XData);h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('측정 ID',repmat(cellstr(r.measurement_id),n,1));
                    h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('셀',repmat(cellstr(r.cell_id),n,1));
                    for f=app.VM.conditionFields()
                        if startsWith(f,"custom_")&&isfinite(r.(f)),h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow(app.label(f),repmat(r.(f),n,1));end
                    end
                    end
                    if app.VM.DisplayMode~="measured"&&~isempty(candidate),app.plotSavedFit(ax,candidate,color,name,r);end
                end
                if isPulse
                    xlabel(ax,'펄스 시작 기준 시간 [s]');xlabel(currentAxes,'펄스 시작 기준 시간 [s]');ylabel(currentAxes,'전류 [A] · 방전 +');grid(currentAxes,'on');xline(ax,0,':','HandleVisibility','off');xline(currentAxes,0,':','HandleVisibility','off');
                    if timeLimits(2)>timeLimits(1),xlim(ax,timeLimits);xlim(currentAxes,timeLimits);end
                    linkaxes([ax,currentAxes],'x');ylim(ax,'auto');ylim(currentAxes,'auto');
                    title(ax,'조건별 펄스 응답 · 점/얇은 선=실측, 굵은 선=선택 모델 피팅');
                else
                    xlabel(ax,'Z′ [mΩ]');ylabel(ax,'−Z″ [mΩ]');axis(ax,'equal');yline(ax,0,':','HandleVisibility','off');title(ax,'조건별 Nyquist · 점=측정, 굵은 선=선택 모델 피팅');
                    if emptyCurves>0,title(ax,"주파수/유도성 범위에 점이 없는 곡선 "+emptyCurves+"개 제외");end
                end
                grid(ax,'on');ax.Toolbar.Visible='on';lg=legend(ax,'show','Location','best','Interpreter','none');lg.ItemHitFcn=@(~,e)app.toggleLegend(e);
                if split,panel.Title=char(app.curveLabel(T(indices(1),:)));end
            end
            app.FrequencyDD.Enable=matlab.lang.OnOffSwitchState(~isPulse);app.InductiveCheck.Enable=app.FrequencyDD.Enable;
        end
        function plotSavedFit(app,ax,c,color,name,r)
            if c.Domain=="EIS"
                f=c.Frequency(:);z=c.Predicted(:);keep=isfinite(f)&isfinite(real(z))&isfinite(imag(z));
                mode=string(app.FrequencyDD.Value);
                if mode=="band",keep=keep&f>=1&f<=1000;elseif mode=="custom",keep=keep&f>=app.FMin.Value&f<=app.FMax.Value;end
                if ~app.InductiveCheck.Value
                    if isfield(c,'Measured')&&numel(c.Measured)==numel(f),keep=keep&imag(c.Measured(:))<=0;else,keep=keep&imag(z)<=0;end
                end
                f=f(keep);z=z(keep);[f,order]=sort(f,'descend');z=z(order);if isempty(f),return,end
                h=plot(ax,real(z)*1000,-imag(z)*1000,'-','LineWidth',2,'Color',color,'Tag','ConditionFittedCurve','DisplayName',[name ' · ' char(c.ModelName)]);
                h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('주파수 [Hz]',f);
            else
                time=c.Time(:);value=c.Predicted(:);if string(app.ResponseDD.Value)=="delta",value=(value-c.Baseline)*1000;end
                keep=isfinite(time)&isfinite(value);if ~any(keep),return,end
                h=plot(ax,time(keep),value(keep),'-','LineWidth',2,'Color',color,'Tag','ConditionFittedCurve','DisplayName',[name ' · ' char(c.ModelName)]);
            end
            n=numel(h.XData);h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('모델',repmat(cellstr(string(c.ModelName)),n,1));
            h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('측정 ID',repmat(cellstr(r.measurement_id),n,1));
            if isfield(c,'Status'),h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('피팅 상태',repmat(cellstr(string(c.Status)),n,1));end
        end
        function toggleLegend(~,event)
            if strcmp(event.Peer.Visible,'on'),event.Peer.Visible='off';else,event.Peer.Visible='on';end
        end
        function name=curveLabel(app,r)
            if app.VM.Variable=="cell_id",name=r.cell_id;
            else,name=app.label(app.VM.Variable)+"="+uecm.axisValueLabel(app.VM.Data,app.VM.Variable,r.(app.VM.Variable));end
            if r.domain=="HPPC",direction="방전";if r.pulse_direction=="charge",direction="충전";end;name=name+" · "+direction+" "+compose('%.3g',r.pulse_amplitude_A)+" A / "+compose('%.4g',r.pulse_duration_s)+" s";end
            name=char(name+" | "+r.cell_id);
        end
        function text=pretty(app,text)
            for f=[app.VM.conditionFields(),"cell_id"],text=replace(text,f,app.label(f));end
        end
        function text=label(app,field)
            if startsWith(string(field),"custom_"),text=app.VM.conditionLabel(field);return,end
            fields=["soc_pct","temperature_C","soh_pct","cycle_number","calendar_days","pulse_amplitude_A","pulse_duration_s","cell_id","temperature_min_C","temperature_max_C","measurement_id","source_id","cell_model"];
            labels=["SOC [%]","온도 [°C]","SOH [%]","사이클 수","경과일 [day]","펄스 |I| [A]","펄스 길이 [s]","셀 개체","온도 최소 [°C]","온도 최대 [°C]","측정 ID","연구/출처","셀 모델"];
            index=find(fields==field,1);text=string(field);if ~isempty(index),text=labels(index);end
        end
        function exportPlots(app)
            folder=uigetdir(pwd,'선택 곡선과 그림을 저장할 새 위치');if isequal(folder,0),return,end
            stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));dest=fullfile(folder,['condition_comparison_' stamp]);mkdir(dest);
            axesList=findall(app.PlotGrid,'Type','axes');for k=1:numel(axesList),exportgraphics(axesList(k),fullfile(dest,sprintf('curve_%02d.png',k)),'Resolution',180);end
            selected=app.VM.Result.Table(app.VM.Selected,:);writetable(selected,fullfile(dest,'selected_measurements.csv'));
            [parameters,curves]=uecm.comparisonFitExport(app.VM.Data,selected,string(app.FitDD.Value));
            writetable(parameters,fullfile(dest,'selected_fit_parameters.csv'));if ~isempty(curves),writetable(curves,fullfile(dest,'saved_fit_samples.csv'));end
            if isfield(app.VM.Data,'AxisCategories'),writelines(jsonencode(app.VM.Data.AxisCategories,'PrettyPrint',true),fullfile(dest,'axis_categories.json'));end
            options=struct('model',string(app.FitDD.Value),'display',app.VM.DisplayMode,'layout',string(app.ModeDD.Value),'response',string(app.ResponseDD.Value),'frequency',string(app.FrequencyDD.Value),'min_Hz',app.FMin.Value,'max_Hz',app.FMax.Value,'include_inductive',app.InductiveCheck.Value,'samples_export','full saved samples; display frequency filter is recorded separately');
            writelines(jsonencode(options,'PrettyPrint',true),fullfile(dest,'comparison_options.json'));
            if isfield(app.VM.Data,'CustomAxes')&&~isempty(app.VM.Data.CustomAxes)
                definitions=app.VM.Data.CustomAxes;writelines(jsonencode(definitions,'PrettyPrint',true),fullfile(dest,'custom_axis_definitions.json'));
            end
            uialert(app.UIFigure,"저장 위치: "+string(dest),'그림 저장 완료','Icon','success');
        end
    end
end
