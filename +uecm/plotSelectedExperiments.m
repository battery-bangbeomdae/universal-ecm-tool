function plotSelectedExperiments(axesList,bundle,indices,showModels)
%PLOTSELECTEDEXPERIMENTS Overlay only checked experiments, separated by domain.
for j=1:4
    ax=axesList{j};tag=ax.Tag;cla(ax,'reset');ax.Tag=tag;hold(ax,'on');grid(ax,'on');
    ax.UserData=struct('FitIndices',[]);
end
filePaths=strings(0,1);
if isfield(bundle,'Fits'),filePaths=string(cellfun(@(f)f.SourceFile,bundle.Fits,'UniformOutput',false));end
files=unique(filePaths,'stable');colors=lines(max(1,numel(files)));
seenEIS=strings(0,1);seenHPPC=strings(0,1);
for j=1:numel(indices)
    k=indices(j);f=bundle.Fits{k};[~,name,ext]=fileparts(f.SourceFile);
    label=name+ext;color=find(files==string(f.SourceFile),1);ink=colors(color,:);
    visible='on';data=struct('FitIndex',k,'SourceFile',string(f.SourceFile),'Domain',f.Domain);
    if f.Domain=="EIS"
        ax=axesList{1};rx=axesList{3};
        if ismember(string(f.SourceFile),seenEIS),visible='off';end
        seenEIS(end+1)=string(f.SourceFile);
        plot(ax,real(f.Measured),-imag(f.Measured),'-o','Color',ink,'DisplayName',label,'HandleVisibility',visible,'UserData',data);
        if showModels,plot(ax,real(f.Predicted),-imag(f.Predicted),'--','Color',ink,'HandleVisibility','off','UserData',data);end
        e=f.Measured-f.Predicted;
        semilogx(rx,f.Frequency,real(e),'-','Color',ink,'DisplayName',label+" Re",'HandleVisibility',visible,'UserData',data);
        semilogx(rx,f.Frequency,imag(e),'--','Color',ink,'DisplayName',label+" Im",'HandleVisibility',visible,'UserData',data);
    else
        ax=axesList{2};rx=axesList{4};
        if ismember(string(f.SourceFile),seenHPPC),visible='off';end
        seenHPPC(end+1)=string(f.SourceFile);
        plot(ax,f.Time,f.Measured,'-','Color',ink,'DisplayName',label,'HandleVisibility',visible,'UserData',data);
        if showModels,plot(ax,f.Time,f.Predicted,'--','Color',ink,'HandleVisibility','off','UserData',data);end
        plot(rx,f.Time,f.Measured-f.Predicted,'Color',ink,'DisplayName',label,'HandleVisibility',visible,'UserData',data);
    end
    ax.UserData.FitIndices(end+1)=k;rx.UserData.FitIndices(end+1)=k;
end
titles=["EIS · 선택 Nyquist","HPPC · 선택 응답","EIS · 잔차","HPPC · 잔차"];
titles(1)="EIS · 선택 Nyquist";
for j=1:4
    ax=axesList{j};hold(ax,'off');
    title(ax,titles(j)+" ("+numel(ax.UserData.FitIndices)+"개)");
    if ~isempty(ax.UserData.FitIndices),legend(ax,'show','Location','best','Interpreter','none');end
end
xlabel(axesList{1},"Z′ [Ω]");ylabel(axesList{1},"−Z″ [Ω]");
xlabel(axesList{2},"펄스 시작부터 시간 [s]");ylabel(axesList{2},"전압 [V]");
xlabel(axesList{3},"주파수 [Hz]");ylabel(axesList{3},"잔차 [Ω]");axesList{3}.XScale='log';
xlabel(axesList{4},"시간 [s]");ylabel(axesList{4},"잔차 [V]");
end
