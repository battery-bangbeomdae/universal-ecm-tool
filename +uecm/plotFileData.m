function data=plotFileData(ax,bundle,file,showModel)
%PLOTFILEDATA Exactly one original-file graph; no SOC/fit requirement.
arguments
    ax
    bundle (1,1) struct
    file (1,1) string
    showModel (1,1) logical = true
end
tag=ax.Tag;cla(ax,'reset');ax.Tag=tag;hold(ax,'on');
data=uecm.filePlotData(bundle,file);T=data.Data;
ax.UserData=struct('SourceFile',file,'Domain',data.Domain,'OriginalRows',data.OriginalRows,'FitIndices',data.FitIndices);
[~,name,ext]=fileparts(file);
if isempty(T),title(ax,name+ext+" · "+data.Note,'Interpreter','none');return,end
if data.Domain=="EIS"&&all(ismember({'real','imag'},T.Properties.VariableNames))
    [x,y]=uecm.segmentPlotRows(T.real,-T.imag,data.Breaks);
    plot(ax,x,y,'-o','MarkerSize',3,'DisplayName','파일 전체 측정','Tag','FileMeasured');
    hold(ax,'on');
    if showModel&&any(isfinite(data.Prediction))
        [x,y]=uecm.segmentPlotRows(real(data.Prediction),-imag(data.Prediction),data.Breaks);
        plot(ax,x,y,'--','DisplayName','피팅 구간 모델','Tag','FilePredicted');
    end
    hold(ax,'off');xlabel(ax,"Z′ [Ω]");ylabel(ax,"−Z″ [Ω]");
elseif data.Domain=="HPPC"&&all(ismember({'time','voltage'},T.Properties.VariableNames))
    yyaxis(ax,'left');[x,y]=uecm.segmentPlotRows(T.time,T.voltage,data.Breaks);
    plot(ax,x,y,'DisplayName','파일 전체 전압','Tag','FileMeasured');hold(ax,'on');
    if showModel&&any(isfinite(data.Prediction))
        [x,y]=uecm.segmentPlotRows(T.time,data.Prediction,data.Breaks);
        plot(ax,x,y,'--','DisplayName','피팅 구간 전압','Tag','FilePredicted');
    end
    hold(ax,'off');ylabel(ax,'전압 [V]');
    if ismember('current',T.Properties.VariableNames)
        yyaxis(ax,'right');hold(ax,'on');[x,y]=uecm.segmentPlotRows(T.time,T.current,data.Breaks);
        plot(ax,x,y,':','DisplayName','파일 전체 전류','Tag','FileCurrent');
        ylabel(ax,'전류 [A]');
        yyaxis(ax,'left');
    end
    xlabel(ax,'파일의 원본 경과 시간 [s]');
else
    title(ax,name+ext+" · 신호 열·단위·분석 종류를 확인하세요",'Interpreter','none');return
end
ax.Tag=tag;ax.UserData=struct('SourceFile',file,'Domain',data.Domain,'OriginalRows',data.OriginalRows,'FitIndices',data.FitIndices);
grid(ax,'on');legend(ax,'show','Location','best','Interpreter','none');
title(ax,name+ext+" | "+data.Domain+" | 전체 "+data.OriginalRows+"행",'Interpreter','none');
end
