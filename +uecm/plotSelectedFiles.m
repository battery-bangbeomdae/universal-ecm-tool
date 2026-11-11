function plotSelectedFiles(axesList,bundle,files,showModels)
%PLOTSELECTEDFILES One complete measured series per file, including unfitted HPPC.
for j=1:4
    ax=axesList{j};tag=ax.Tag;cla(ax,'reset');ax.Tag=tag;
    ax.UserData=struct('Files',strings(0,1),'FitIndices',[]);
end
files=string(files(:));colors=lines(max(1,numel(files)));
for k=1:numel(files)
    d=uecm.filePlotData(bundle,files(k));T=d.Data;
    if isempty(T),continue,end
    [~,name,ext]=fileparts(files(k));label=name+ext;ink=colors(k,:);
    meta=struct('SourceFile',files(k),'Domain',d.Domain,'OriginalRows',d.OriginalRows);
    if d.Domain=="EIS"&&all(ismember({'frequency','real','imag'},T.Properties.VariableNames))
        ax=axesList{1};rx=axesList{3};hold(ax,'on');hold(rx,'on');
        [x,y]=uecm.segmentPlotRows(T.real,-T.imag,d.Breaks);
        plot(ax,x,y,'-o','MarkerSize',3,'Color',ink,'DisplayName',label,'Tag','FileMeasured','UserData',meta);
        if showModels&&any(isfinite(d.Prediction))
            [x,y]=uecm.segmentPlotRows(real(d.Prediction),-imag(d.Prediction),d.Breaks);
            plot(ax,x,y,'--','Color',ink,'HandleVisibility','off','Tag','FilePredicted','UserData',meta);
        end
        e=complex(T.real,T.imag)-d.Prediction;
        if any(isfinite(e))
            [x,y]=uecm.segmentPlotRows(T.frequency,real(e),d.Breaks);
            semilogx(rx,x,y,'Color',ink,'DisplayName',label+" Re",'UserData',meta);
            [x,y]=uecm.segmentPlotRows(T.frequency,imag(e),d.Breaks);
            semilogx(rx,x,y,'--','Color',ink,'DisplayName',label+" Im",'UserData',meta);
        end
    elseif d.Domain=="HPPC"&&all(ismember({'time','voltage'},T.Properties.VariableNames))
        ax=axesList{2};rx=axesList{4};yyaxis(ax,'left');hold(ax,'on');hold(rx,'on');
        [x,y]=uecm.segmentPlotRows(T.time,T.voltage,d.Breaks);
        plot(ax,x,y,'-','Color',ink,'DisplayName',label+" 전압",'Tag','FileMeasured','UserData',meta);
        if showModels&&any(isfinite(d.Prediction))
            [x,y]=uecm.segmentPlotRows(T.time,d.Prediction,d.Breaks);
            plot(ax,x,y,'--','Color',ink,'HandleVisibility','off','Tag','FilePredicted','UserData',meta);
        end
        if ismember('current',T.Properties.VariableNames)
            yyaxis(ax,'right');hold(ax,'on');[x,y]=uecm.segmentPlotRows(T.time,T.current,d.Breaks);
            plot(ax,x,y,':','Color',ink,'DisplayName',label+" 전류",'Tag','FileCurrent','UserData',meta);
            ylabel(ax,'전류 [A]');yyaxis(ax,'left');
        end
        e=T.voltage-d.Prediction;
        if any(isfinite(e))
            [x,y]=uecm.segmentPlotRows(T.time,e,d.Breaks);
            plot(rx,x,y,'Color',ink,'DisplayName',label,'UserData',meta);
        end
    else,continue,end
    ax.UserData.Files(end+1,1)=files(k);rx.UserData.Files(end+1,1)=files(k);
    ax.UserData.FitIndices=[ax.UserData.FitIndices,d.FitIndices];
    rx.UserData.FitIndices=ax.UserData.FitIndices;
end
titles=["EIS · 파일 전체 Nyquist","HPPC · 파일 전체 전압·전류","EIS · 피팅 구간 잔차","HPPC · 피팅 구간 잔차"];
for j=1:4
    ax=axesList{j};hold(ax,'off');grid(ax,'on');
    title(ax,titles(j)+" ("+numel(ax.UserData.Files)+"파일)");
    if ~isempty(findall(ax,'Type','line')),legend(ax,'show','Location','best','Interpreter','none');end
end
xlabel(axesList{1},"Z′ [Ω]");ylabel(axesList{1},"−Z″ [Ω]");
yyaxis(axesList{2},'left');xlabel(axesList{2},"파일의 원본 경과 시간 [s]");ylabel(axesList{2},"전압 [V]");
xlabel(axesList{3},"주파수 [Hz]");ylabel(axesList{3},"잔차 [Ω]");axesList{3}.XScale='log';
xlabel(axesList{4},"원본 경과 시간 [s]");ylabel(axesList{4},"잔차 [V]");
end
