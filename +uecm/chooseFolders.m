function folders=chooseFolders(initial)
%CHOOSEFOLDERS Pick several experiment directories, including across parents.
arguments
    initial (1,1) string = string(pwd)
end
if ~isfolder(initial),initial=string(pwd);end
folders=strings(0,1);selected=strings(0,1);current=initial;
f=uifigure('Name','실험 폴더 다중 선택','Position',[100,100,840,570], ...
    'WindowStyle','modal','Tag','ExperimentFolderPicker','CloseRequestFcn',@cancel);
cleanup=onCleanup(@()delete(f));
g=uigridlayout(f,[6,3]);g.RowHeight={48,36,30,'1x',36,40};g.ColumnWidth={'1x',125,125};
l=uilabel(g,'Text','왼쪽에서 Ctrl/⌘·Shift로 여러 폴더를 선택하고 목록에 추가하세요. 다른 위치의 폴더도 추가한 뒤 한 번에 가져옵니다. 상위 폴더를 선택하면 모든 깊이의 하위 폴더를 읽습니다. 현재 위치 전체 가져오기로 바로 읽을 수도 있습니다.','WordWrap','on');l.Layout.Column=[1,3];
path=uieditfield(g,'text','Value',char(current),'Tag','FolderPickerPath','ValueChangedFcn',@pathChanged);
uibutton(g,'Text','상위 폴더','ButtonPushedFcn',@up);
uibutton(g,'Text','위치 찾아보기','ButtonPushedFcn',@browse);
l=uilabel(g,'Text','현재 위치의 하위 폴더');l.Layout.Column=1;
l=uilabel(g,'Text','가져올 폴더 목록');l.Layout.Column=[2,3];
candidates=uilistbox(g,'Multiselect','on','Tag','FolderCandidates');candidates.Layout.Column=1;
chosen=uilistbox(g,'Multiselect','on','Tag','ChosenFolders');chosen.Layout.Column=[2,3];
nav=uigridlayout(g,[1,3]);nav.Layout.Column=1;nav.Padding=[0,0,0,0];nav.ColumnWidth={'1x','1x','1x'};
uibutton(nav,'Text','선택 폴더 열기','ButtonPushedFcn',@openSelected);
uibutton(nav,'Text','선택 추가 →','Tag','AddSelectedFolders','ButtonPushedFcn',@addSelected);
uibutton(nav,'Text','현재 위치 추가','ButtonPushedFcn',@addCurrent);
b=uibutton(g,'Text','목록에서 제거','ButtonPushedFcn',@removeSelected);b.Layout.Column=[2,3];
uibutton(g,'Text','현재 폴더 전체 가져오기','Tag','ImportCurrentFolder','ButtonPushedFcn',@acceptCurrent);
b=uibutton(g,'Text','취소','ButtonPushedFcn',@cancel);b.Layout.Column=2;
b=uibutton(g,'Text','선택 폴더 가져오기','Tag','ImportChosenFolders','ButtonPushedFcn',@accept);b.Layout.Column=3;
refresh();uiwait(f);clear cleanup
    function refresh()
        path.Value=char(current);d=dir(current);d=d([d.isdir]);names=string({d.name});names=names(~ismember(names,[".",".."])&~startsWith(names,"."));
        candidates.Items=cellstr(sort(names));candidates.Value={};
        chosen.Items=cellstr(selected);chosen.Value={};
    end
    function setCurrent(value)
        if isfolder(value),current=string(value);refresh();
        else,path.Value=char(current);uialert(f,'존재하는 폴더를 선택하세요.','폴더 확인');end
    end
    function pathChanged(src,~),setCurrent(string(src.Value));end
    function up(~,~),setCurrent(string(fileparts(current)));end
    function browse(~,~)
        value=uigetdir(current,'실험 폴더가 있는 위치');if ~isequal(value,0),setCurrent(string(value));end
    end
    function openSelected(~,~)
        v=string(candidates.Value);if numel(v)==1,setCurrent(fullfile(current,v));end
    end
    function addSelected(~,~)
        v=string(candidates.Value);if isempty(v),return,end
        selected=unique([selected;reshape(string(fullfile(current,v)),[],1)],'stable');refresh();
    end
    function addCurrent(~,~),selected=unique([selected;current],'stable');refresh();end
    function removeSelected(~,~),selected=selected(~ismember(selected,string(chosen.Value)));refresh();end
    function accept(~,~)
        if isempty(selected)
            v=string(candidates.Value);
            if isempty(v),selected=current;else,selected=reshape(string(fullfile(current,v)),[],1);end
        end
        folders=selected;uiresume(f);
    end
    function acceptCurrent(~,~),folders=current;uiresume(f);end
    function cancel(~,~),folders=strings(0,1);uiresume(f);end
end
