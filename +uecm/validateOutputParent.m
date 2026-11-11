function parent=validateOutputParent(parent)
%VALIDATEOUTPUTPARENT Common canonical output location and measurement-only guard.
% merged 2026-11-10: protected paths are refused BEFORE the existence check
% (a protected folder that does not exist yet is still refused), and the
% comparison ignores case on Windows (C:\Data == c:\data).
arguments
 parent (1,1) string
end
paths=uecm.workspacePaths();
refuse(parent,paths);
if ~isfolder(parent),error('uecm:Output','저장할 상위 폴더를 먼저 골라 주세요.');end
[ok,attr]=fileattrib(parent);if ~ok,error('uecm:Output','저장 경로를 확인할 수 없습니다.');end
parent=string(attr.Name);
refuse(parent,paths);   % again on the canonical (symlink/short-name resolved) path
end

function refuse(parent,paths)
for name=["raw","extracted","derived"]
 protected=string(fullfile(paths.GHRoot,'data',name));
 if strcmpi(parent,protected)&&ispc||parent==protected||startsWith(parent,protected+filesep,'IgnoreCase',ispc)
  error('uecm:ProtectedOutput','원본/측정 전용 폴더에는 결과를 저장하지 않습니다. 다른 폴더를 골라 주세요.');
 end
end
end
