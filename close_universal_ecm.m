function count=close_universal_ecm()
%CLOSE_UNIVERSAL_ECM Close v8.1 windows, bypassing a stale native close callback.
%   close_universal_ecm closes only Universal ECM Tool v8.1 primary windows
%   and asks their owners to cancel owned background work and auxiliary views.
%   MATLAB and unrelated figures remain open. Unsaved results are not exported.
figures=findall(groot,'Type','figure');count=0;
for k=1:numel(figures)
    fig=figures(k);
    if ~isvalid(fig)||~startsWith(string(fig.Name),"Universal ECM Tool v8.1"),continue,end
    owner=[];
    if isappdata(fig,'UniversalECMApp')
        stored=getappdata(fig,'UniversalECMApp');
        if isstruct(stored)&&isfield(stored,'view'),owner=stored.view;end
    end
    % Delete the native window first; an older CloseRequestFcn cannot veto it.
    fig.CloseRequestFcn=[];fig.DeleteFcn=[];delete(fig);drawnow nocallbacks;count=count+1;
    if ~isempty(owner)&&isvalid(owner),delete(owner);end
end
end
