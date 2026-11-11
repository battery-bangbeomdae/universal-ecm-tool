function drawCircuit(ax,c)
%DRAWCIRCUIT Actual series/parallel topology of the selected candidate.
arguments
    ax
    c (1,1) struct
end
cla(ax,'reset');ax.Tag='ECMCircuit';hold(ax,'on');wireColor=ax.XColor;p=c.Parameters;two=startsWith(c.ModelName,"2RC");
x=0.3;y=.65;
if c.Domain=="HPPC",source(x);x=x+1.5;name="R0";
else,name="Rs";end
if c.ModelName=="ZarcL",block(x,"L");x=x+1.5;end
resistor(x,x+.2,x+1.15,x+1.5,y,name);x=x+1.5;
if isfield(p,'Rct_Ohm')&&isfinite(p.Rct_Ohm)
    if ismember(c.ModelName,["ZarcL","CPE","CPE+W"]),cap="CPE";else,cap="Cdl";end
    parallel(x,"Rct",cap);x=x+2.3;
else
    if startsWith(c.ModelName,"2CPE")
        parallel(x,"R1","CPE1");x=x+2.3;
        parallel(x,"R2","CPE2");x=x+2.3;
    else
        parallel(x,"R1","C1");x=x+2.3;
        if two,parallel(x,"R2","C2");x=x+2.3;end
    end
end
if endsWith(c.ModelName,"+W"),block(x,"W");x=x+1.5;end
line(ax,[x-.3,x],[y,y],'LineWidth',1.5,'Color',wireColor);plot(ax,[.3,x],[y,y],'o','Color',wireColor);
xlim(ax,[0,x+.3]);ylim(ax,[-.38,1.55]);daspect(ax,[1,1,1]);axis(ax,'off');title(ax,c.ModelName,'Interpreter','none');hold(ax,'off');
    function source(start)
        center=start+.7;line(ax,[start,center-.22],[y,y],'Color',wireColor,'LineWidth',1.5);
        rectangle(ax,'Position',[center-.22,y-.22,.44,.44],'Curvature',[1,1],'LineWidth',1.4,'EdgeColor',wireColor);
        line(ax,[center+.22,start+1.5],[y,y],'Color',wireColor,'LineWidth',1.5);
        text(ax,center-.1,y,'+','HorizontalAlignment','center','Color',wireColor);
        text(ax,center+.1,y,'−','HorizontalAlignment','center','Color',wireColor);
        text(ax,center,y+.4,"Ubase",'HorizontalAlignment','center','Interpreter','none');
    end
    function block(start,label)
        line(ax,[start,start+.2],[y,y],'LineWidth',1.5,'Color',wireColor);rectangle(ax,'Position',[start+.2,y-.13,.95,.26],'LineWidth',1.4);
        line(ax,[start+1.15,start+1.5],[y,y],'LineWidth',1.5,'Color',wireColor);
        text(ax,start+.68,y+.4,label,'HorizontalAlignment','center','Interpreter','none','FontSize',12);
    end
    function resistor(left,start,stop,right,level,label)
        toothX=linspace(start,stop,8);
        toothY=level+[0,.13,-.13,.13,-.13,.13,-.13,0];
        line(ax,[left,toothX,right],[level,toothY,level], ...
            'LineWidth',1.5,'Color',wireColor,'Tag','ResistorSymbol');
        text(ax,(start+stop)/2,level+.3,label,'HorizontalAlignment','center', ...
            'Interpreter','none','FontSize',12);
    end
    function parallel(start,label,cap)
        left=start;right=start+2;top=1.05;bottom=.15;
        line(ax,[left,left],[bottom,top],'LineWidth',1.5,'Color',wireColor);line(ax,[right,right],[bottom,top],'LineWidth',1.5,'Color',wireColor);
        resistor(left,left+.45,left+1.55,right,top,label);
        if startsWith(cap,'CPE')
            line(ax,[left,left+.45],[bottom,bottom],'LineWidth',1.5,'Color',wireColor);rectangle(ax,'Position',[left+.45,bottom-.12,1.1,.24]);line(ax,[left+1.55,right],[bottom,bottom],'Color',wireColor);
        else
            line(ax,[left,left+.9],[bottom,bottom],'LineWidth',1.5,'Color',wireColor);line(ax,[left+.9,left+.9],[bottom-.17,bottom+.17],'LineWidth',1.5,'Color',wireColor);
            line(ax,[left+1.1,left+1.1],[bottom-.17,bottom+.17],'LineWidth',1.5,'Color',wireColor);line(ax,[left+1.1,right],[bottom,bottom],'LineWidth',1.5,'Color',wireColor);
        end
        text(ax,left+1,bottom-.4,cap,'HorizontalAlignment','center','Interpreter','none','FontSize',12);
        line(ax,[right,right+.3],[y,y],'LineWidth',1.5,'Color',wireColor);
    end
end
