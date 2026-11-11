function match=fitSignatureMatches(saved,current)
%FITSIGNATUREMATCHES Retain numerical compatibility across UI/import-only edits.
match=isequal(saved,current);if match,return,end
if ~isstring(saved)||isempty(saved)||saved(1)~=string(version),match=false;return,end
% Require byte-identical numerical solvers and their package dependencies.
% Prepared signal/group equality and fitConfiguration are checked separately.
root=fileparts(mfilename('fullpath'));
pending=["fitEIS","fitHPPC","linKK","analyze","compareCandidates","candidateRow"];
seen=strings(0,1);
while ~isempty(pending)
 name=pending(1);pending(1)=[];if ismember(name,seen),continue,end
 seen(end+1)=name;
 if ismember(name,["prepare","analysisPrepared","analyzeBatch"]),continue,end
 file=fullfile(root,name+".m");if ~isfile(file),match=false;return,end
 code=string(fileread(file));if ~any(saved==code),match=false;return,end
 tokens=regexp(char(code),'uecm\.([A-Za-z]\w*)\s*\(','tokens');
 for k=1:numel(tokens),pending(end+1)=string(tokens{k}{1});end
end
match=true;
end
