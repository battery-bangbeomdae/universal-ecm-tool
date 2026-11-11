function [tri,message] = surfaceMesh(T,xname,yname,zname)
%SURFACEMESH Conservative local connections of observed fitted points, no extrapolation.
arguments
    T table
    xname (1,1) string
    yname (1,1) string
    zname (1,1) string
end
tri=[];message="";
if height(T)<4,message="면을 만들 점이 부족해서 측정 위치의 점만 보여 줍니다.";return,end
if any(T.cell_id=="unassigned"),message="셀 ID가 없어 같은 셀인지 확인할 수 없습니다. 점으로만 보여 줍니다.";return,end
for name=["source_id","cell_id","domain","circuit"]
    if numel(unique(T.(name)))>1,message="출처·셀·방법·회로가 달라 한 면으로 연결하지 않습니다. 그룹을 골라 주세요.";return,end
end
for name=["soc_pct","temperature_C","soh_pct","cycle_number"]
    if ismember(name,[xname,yname]),continue,end
    v=T.(name);v=v(isfinite(v));
    if numel(unique(v))>1,message="선택하지 않은 조건("+name+")도 달라 면 연결을 보류합니다.";return,end
end
x=T.(xname);y=T.(yname);
if rangeBase(x)==0||rangeBase(y)==0,message="축 중 하나가 한 값뿐입니다. 점·선만 확인할 수 있습니다.";return,end
xy=[(x-min(x))/rangeBase(x),(y-min(y))/rangeBase(y)];
if size(unique(xy,'rows'),1)~=size(xy,1)
    message="같은 조건의 반복값이 있습니다. 임의 평균을 내지 않고 점으로 보여 줍니다.";return,end
if rank(xy-mean(xy,1))<2,message="두 축이 한 줄로만 변해서 면을 만들 수 없습니다.";return,end
tri=delaunay(xy(:,1),xy(:,2));
d=sqrt(sum((reshape(xy,size(xy,1),1,2)-reshape(xy,1,size(xy,1),2)).^2,3));d(d==0)=Inf;
limit=2.5*median(min(d,[],2));
lengths=[d(sub2ind(size(d),tri(:,1),tri(:,2))),d(sub2ind(size(d),tri(:,2),tri(:,3))),d(sub2ind(size(d),tri(:,3),tri(:,1)))];
tri=tri(all(lengths<=limit,2),:);
if isempty(tri),message="점 사이 빈 구간이 커서 면을 연결하지 않았습니다.";
else,message="관측점의 추정값만 삼각형으로 연결했습니다. 빈 영역의 예측 모델은 아닙니다.";end
end
function r=rangeBase(x)
r=max(x)-min(x);
end
