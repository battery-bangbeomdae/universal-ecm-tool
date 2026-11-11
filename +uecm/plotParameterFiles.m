function [axesList,shown]=plotParameterFiles(parent,bundle,indices,x,y,z,layout,options)
%PLOTPARAMETERFILES Plot actual per-file ECM points together or in scrollable axes.
arguments
    parent
    bundle struct
    indices double
    x string
    y string
    z string
    layout string = "combined"
    options struct = struct()
end
if ~isfield(options,'Model'),options.Model="권장 모델";end
if ~isfield(options,'Filters'),options.Filters=struct();end
if ~isfield(options,'Rotate'),options.Rotate=true;end
if ~isfield(options,'AxisTag'),options.AxisTag="OverlayParameterMap";end
if ~isfield(options,'LegendLocation'),options.LegendLocation="northeastoutside";end
if ~isfield(options,'ContinueFcn'),options.ContinueFcn=[];end
is3=y~="none";shown=[];axesList={};
if ~canContinue(options)||~isvalid(parent),return,end
oldAxes=findall(parent,'Tag',options.AxisTag);
if ~isfield(bundle,'Results')||~isfield(bundle,'Fits')||isempty(indices)
    if isempty(oldAxes),ax=uiaxes(parent,'Tag',options.AxisTag);else,ax=oldAxes(1);cla(ax);delete(oldAxes(2:end));end
    ax.Visible='on';ax.UserData=struct('FitIndices',[],'Parameter',z,'SourceFile',"*");title(ax,'표시할 값이 없습니다 · 파일/축/조건 필터를 확인하세요.');axesList={ax};return
end
R=bundle.Results;indices=indices(indices>=1&indices<=height(R));
uecm.filterMapConditions(R(indices,:),options.Filters,[x,y]); % Validate before touching visible graphics.
paths=string(R.source_file);files=unique(paths(indices),'stable');colors=lines(max(1,numel(files)));
if isempty(files),files="*";end
if ~isvalid(parent),return,end
if layout=="split",owners=files;parent.RowHeight=repmat({420},1,numel(files));else,owners="*";parent.RowHeight={'1x'};end
parent.ColumnWidth={'1x'};parent.Scrollable='on';
for a=1:numel(owners)
    if ~canContinue(options),return,end
    ax=[];sameOwner=false;previousView=[];previous3=false;
    for n=1:numel(oldAxes)
        candidate=oldAxes(n);
        if isvalid(candidate)&&~any(cellfun(@(h)h==candidate,axesList))&&isstruct(candidate.UserData)&&isfield(candidate.UserData,'SourceFile')&&string(candidate.UserData.SourceFile)==owners(a)
            ax=candidate;sameOwner=true;break
        end
    end
    if isempty(ax)
        for n=1:numel(oldAxes)
            if isvalid(oldAxes(n))&&~any(cellfun(@(h)h==oldAxes(n),axesList)),ax=oldAxes(n);break,end
        end
    end
    if isempty(ax),ax=uiaxes(parent,'Tag',options.AxisTag);
    else,previousView=ax.View;previous3=isequal(getappdata(ax,'ECMIs3D'),true);legend(ax,'off');cla(ax);end
    ax.Visible='on';ax.Layout.Row=a;ax.Layout.Column=1;
    ax.XLimMode='auto';ax.YLimMode='auto';ax.ZLimMode='auto';hold(ax,'on');keepIndices=[];
    for k=1:numel(files)
        if ~canContinue(options),return,end
        if owners(a)~="*"&&owners(a)~=files(k),continue,end
        rows=indices(paths(indices)==files(k));values=NaN(numel(rows),1);
        for q=1:numel(rows)
            if mod(q-1,64)==0&&~canContinue(options),return,end
            f=bundle.Fits{rows(q)};
            if options.Model~="권장 모델"
                cc=uecm.candidatesOf(f);hit=find(cellfun(@(c)c.ModelName==options.Model,cc),1);
                if isempty(hit),continue,end
                f=cc{hit};
            end
            if isfield(f.Parameters,z),values(q)=f.Parameters.(z);end
        end
        T=R(rows,:);
        needed=[x,z];if is3,needed=[x,y,z];end
        if ~all(ismember(needed,string(T.Properties.VariableNames))),continue,end
        T.(z)=values;valid=isfinite(T.(x))&isfinite(values);
        if is3,valid=valid&isfinite(T.(y));end
        [allowed,~]=uecm.filterMapConditions(T,options.Filters,[x,y]);valid=valid&allowed;
        T=T(valid,:);rows=rows(valid);if isempty(rows),continue,end
        [~,name,ext]=fileparts(files(k));label="["+k+"] "+name+ext;
        if is3,h=scatter3(ax,T.(x),T.(y),T.(z),58,colors(k,:),'filled','DisplayName',label);
        else,h=scatter(ax,T.(x),T.(z),58,colors(k,:),'filled','DisplayName',label);end
        h.Tag='OverlayParameterSeries';h.UserData=struct('SourceFile',files(k),'FitIndices',rows);
        h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('fit_id',T.fit_id);
        h.DataTipTemplate.DataTipRows(end+1)=dataTipTextRow('파일',repmat(files(k),height(T),1));
        keepIndices=[keepIndices;rows(:)]; %#ok<AGROW>
    end
    xlabel(ax,strrep(x,'_',' '),'Interpreter','none');grid(ax,'on');ax.FontSize=13;
    if is3
        ylabel(ax,strrep(y,'_',' '),'Interpreter','none');zlabel(ax,strrep(z,'_',' '),'Interpreter','none');
        if sameOwner&&previous3&&~isempty(previousView),view(ax,previousView);else,view(ax,3);end
        if options.Rotate,ax.Interactions=[rotateInteraction,zoomInteraction,dataTipInteraction];else,ax.Interactions=[panInteraction,zoomInteraction,dataTipInteraction];end
        uecm.applyCategoryTicks(ax,bundle,x,y,z);
    else
        ylabel(ax,strrep(z,'_',' '),'Interpreter','none');zlabel(ax,'');view(ax,2);ax.Interactions=[panInteraction,zoomInteraction,dataTipInteraction];uecm.applyCategoryTicks(ax,bundle,x,z,"");
    end
    if owners(a)=="*",heading="여러 파일 한 그래프";else,[~,n,e]=fileparts(owners(a));heading=n+e;end
    title(ax,heading+" · "+options.Model,'Interpreter','none');
    if ~isempty(keepIndices),legend(ax,'show','Location',options.LegendLocation,'Interpreter','none');end
    ax.UserData=struct('FitIndices',keepIndices,'Parameter',z,'SourceFile',owners(a));ax.Toolbar.Visible='on';setappdata(ax,'ECMIs3D',is3);hold(ax,'off');
    axesList{end+1}=ax;shown=[shown;keepIndices]; %#ok<AGROW>
end
for n=1:numel(oldAxes)
    if isvalid(oldAxes(n))&&~any(cellfun(@(h)h==oldAxes(n),axesList)),delete(oldAxes(n));end
end

end

function alive=canContinue(options)
alive=isempty(options.ContinueFcn)||options.ContinueFcn();
end
