function plotSelectedFitData(axesList,bundle,files,indices,measured,models,showModels,continueFcn)
%PLOTSELECTEDFITDATA Checked datasets and checked candidate models only.
if nargin<8,continueFcn=[];end
if ~isempty(continueFcn)&&~continueFcn(),return,end
for j=1:4
    ax=axesList{j};tag=ax.Tag;cla(ax,'reset');ax.Tag=tag;hold(ax,'on');grid(ax,'on');
    ax.UserData=struct('Files',strings(0,1),'FitIndices',[]);
end
files=string(files(:));colors=lines(max(1,numel(files)));seen=strings(0,1);
names=["1RC","2RC","ZarcL","1RC+W","2RC+W","CPE+W","2CPE+W","CPE","2CPE"];styles=["--","-.",":","--","-.",":","-.",":","-."];
for k=indices(:)'
    if ~isempty(continueFcn)&&~continueFcn(),return,end
    f=bundle.Fits{k};file=string(f.SourceFile);color=find(files==file,1);if isempty(color),continue,end
    ink=colors(color,:);[~,stem,ext]=fileparts(file);label=stem+ext;if strlength(label)>24,label=extractBefore(label,22)+"…";end
    if f.Domain=="EIS",ax=axesList{1};rx=axesList{3};x=f.Frequency;
    else
        ax=axesList{2};rx=axesList{4};if numel(ax.YAxis)>1,yyaxis(ax,'left');end;hold(ax,'on');
        raw=uecm.filePlotData(bundle,file);offset=sourceOffset(bundle,file);
        x=raw.Data.time(f.SourceRows-offset);
    end
    info=struct('SourceFile',file,'FitIndex',k,'Domain',f.Domain,'Model',"measured");
    if measured(k)
        visibility=first(file+"|measured");
        if f.Domain=="EIS"
            plot(ax,real(f.Measured),-imag(f.Measured),'-o','MarkerSize',3,'Color',ink,'DisplayName',label+" 측정",'HandleVisibility',visibility,'Tag','SelectedMeasured','UserData',info);
        else
            plot(ax,x,f.Measured,'-','Color',ink,'DisplayName',label+" 측정",'HandleVisibility',visibility,'Tag','SelectedMeasured','UserData',info);
        end
    end
    cc=uecm.candidatesOf(f);
    for j=1:numel(cc)
        c=cc{j};model=find(names==c.ModelName,1);
        if isempty(model)||model>size(models,2)||~models(k,model),continue,end
        info.Model=c.ModelName;
        if showModels
            visibility=first(file+"|"+c.ModelName);
            if f.Domain=="EIS"
                plot(ax,real(c.Predicted),-imag(c.Predicted),char(styles(model)),'Color',ink,'DisplayName',label+" "+c.ModelName, ...
                    'HandleVisibility',visibility,'Tag','SelectedPrediction','UserData',info);
            else
                plot(ax,x,c.Predicted,char(styles(model)),'Color',ink,'DisplayName',label+" "+c.ModelName, ...
                    'HandleVisibility',visibility,'Tag','SelectedPrediction','UserData',info);
            end
        end
        e=c.Measured-c.Predicted;
        visibility=first(file+"|residual|"+c.ModelName);
        if f.Domain=="EIS"
            semilogx(rx,c.Frequency,real(e),char(styles(model)),'Color',ink,'DisplayName',label+" "+c.ModelName+" Re", ...
                'HandleVisibility',visibility,'Tag','SelectedResidual','UserData',info);
            semilogx(rx,c.Frequency,imag(e),':','Color',ink,'DisplayName',label+" "+c.ModelName+" Im", ...
                'HandleVisibility',visibility,'Tag','SelectedResidual','UserData',info);
        else
            plot(rx,x,e,char(styles(model)),'Color',ink,'DisplayName',label+" "+c.ModelName, ...
                'HandleVisibility',visibility,'Tag','SelectedResidual','UserData',info);
        end
    end
    ax.UserData.Files=union(ax.UserData.Files,file,'stable');rx.UserData.Files=ax.UserData.Files;
    ax.UserData.FitIndices(end+1)=k;rx.UserData.FitIndices(end+1)=k;
end
% No-fit files retain full raw visibility; there are no dataset boxes yet.
for file=files'
    if ~isempty(continueFcn)&&~continueFcn(),return,end
    allIndices=[];
    if isfield(bundle,'Fits'),allIndices=find(cellfun(@(f)string(f.SourceFile)==file,bundle.Fits));end
    if ~isempty(allIndices),continue,end
    d=uecm.filePlotData(bundle,file);T=d.Data;if isempty(T),continue,end
    color=find(files==file,1);ink=colors(color,:);[~,stem,ext]=fileparts(file);
    info=struct('SourceFile',file,'FitIndex',0,'Domain',d.Domain,'Model',"raw");
    if d.Domain=="HPPC"&&all(ismember({'time','voltage'},T.Properties.VariableNames))
        ax=axesList{2};yyaxis(ax,'left');hold(ax,'on');[x,y]=uecm.segmentPlotRows(T.time,T.voltage,d.Breaks);
        plot(ax,x,y,'Color',ink,'DisplayName',stem+ext+" 원본(피팅 전)",'Tag','SelectedRaw','UserData',info);
        if ismember('current',T.Properties.VariableNames)
            yyaxis(ax,'right');hold(ax,'on');[x,y]=uecm.segmentPlotRows(T.time,T.current,d.Breaks);
            plot(ax,x,y,':','Color',ink,'DisplayName',stem+ext+" 전류",'Tag','SelectedRawCurrent','UserData',info);
            ylabel(ax,'전류 [A]');yyaxis(ax,'left');
        end
        ax.UserData.Files(end+1,1)=file;
    elseif d.Domain=="EIS"&&all(ismember({'real','imag'},T.Properties.VariableNames))
        ax=axesList{1};[x,y]=uecm.segmentPlotRows(T.real,-T.imag,d.Breaks);
        plot(ax,x,y,'-o','MarkerSize',3,'Color',ink,'DisplayName',stem+ext+" 원본(피팅 전)",'Tag','SelectedRaw','UserData',info);
        ax.UserData.Files(end+1,1)=file;
    end
end
titles=["EIS · 체크한 측정/모델","HPPC · 체크한 측정/모델","EIS · 체크한 모델 잔차","HPPC · 체크한 모델 잔차"];
for j=1:4
    ax=axesList{j};hold(ax,'off');grid(ax,'on');title(ax,titles(j));
    if ~isempty(findall(ax,'Type','line')),legend(ax,'show','Location','best','Interpreter','none');end
end
xlabel(axesList{1},"Z′ [Ω]");ylabel(axesList{1},"−Z″ [Ω]");
if numel(axesList{2}.YAxis)>1,yyaxis(axesList{2},'left');end;
uecm.scaleResidualAxes(axesList{3});uecm.scaleResidualAxes(axesList{4});
xlabel(axesList{2},"원본 경과 시간 [s]");ylabel(axesList{2},"전압 [V]");
xlabel(axesList{3},"주파수 [Hz]");ylabel(axesList{3},"잔차 [Ω]");axesList{3}.XScale='log';
xlabel(axesList{4},"원본 경과 시간 [s]");ylabel(axesList{4},"잔차 [V]");
    function value=first(key)
        value='on';if ismember(key,seen),value='off';else,seen(end+1)=key;end
    end
end
function offset=sourceOffset(bundle,file)
offset=0;
if isfield(bundle.Prepared,'FilePrepared')
    for j=1:numel(bundle.Prepared.FilePrepared)
        q=bundle.Prepared.FilePrepared{j};if string(q.Input.File)==file,break,end
        offset=offset+height(q.Input.Data);
    end
end
end
