function [bundle,report]=addSelectedAxes(bundle,M,columns,keys,source)
%ADDSELECTEDAXES Atomically validate and add explicitly checked CSV columns.
columns=string(columns(:)');keys=string(keys(:)');
if isempty(columns),error('uecm:CustomAxis','열 제목의 체크박스에서 추가할 변수를 선택하세요.');end
if isempty(keys),error('uecm:CustomAxis','연결 키를 선택하세요. 행 순서만으로는 연결하지 않습니다.');end
if ~all(ismember([columns,keys],string(M.Properties.VariableNames)))||any(ismember(columns,keys))||numel(unique(columns))~=numel(columns)
 error('uecm:CustomAxis','변수 열과 식별 키를 확인하세요.');end
M=M(:,cellstr(unique([keys,columns],'stable')));categories=cell(size(columns));kinds=strings(size(columns));
for k=1:numel(columns),[M.(columns(k)),categories{k},kinds(k)]=uecm.customColumnValues(M.(columns(k)));end
% Repeated raw rows are safe only when every selected value agrees, including missingness.
[~,first]=unique(M,'rows','stable');M=M(sort(first),:);
if height(unique(M(:,cellstr(keys)),'rows'))~=height(M)
 error('uecm:CustomAxis','같은 측정 키에 서로 다른 변수 값이 있습니다. 연결 키를 더 선택하거나 측정별 조건표를 사용하세요.');
end
messages=strings(size(columns));
for k=1:numel(columns)
 col=columns(k);internal=col;field=string(matlab.lang.makeValidName("custom_"+internal));
 if ismember(field,string(bundle.Results.Properties.VariableNames))
  hit=[];if isfield(bundle,'CustomAxes'),hit=find(string({bundle.CustomAxes.Field})==field,1);end
  if ~isempty(hit)&&startsWith(string(bundle.CustomAxes(hit).Source),"imported:")
   internal="selected_"+col;
  end
 end
 if internal~=col,M.(internal)=M.(col);end
 label=col;if kinds(k)=="범주",label=label+" (범주)";end
 [bundle,messages(k)]=uecm.addCustomAxis(bundle,M,internal,label,"",keys,source);
 field=string(matlab.lang.makeValidName("custom_"+internal));at=find(string({bundle.CustomAxes.Field})==field,1);bundle.CustomAxes(at).Column=col;
 if ~isempty(categories{k})
  entry=struct('Field',field,'Values',categories{k});
  if ~isfield(bundle,'AxisCategories')||isempty(bundle.AxisCategories),bundle.AxisCategories=entry;else,bundle.AxisCategories(end+1)=entry;end
 end
end
report="변수 "+numel(columns)+"개 추가 완료. "+join(messages," ");
end
