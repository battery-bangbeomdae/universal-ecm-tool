function match=fitPieceMatches(piece,q,checkOptions)
%FITPIECEMATCHES Validate loaded signals/grouping/conditions before reusing a fit.
if nargin<3,checkOptions=true;end
match=false;if isempty(piece)||~isfield(piece,'Prepared')||q.Blocked,return,end
if ~isfield(piece,'ComputationSchema')||string(piece.ComputationSchema)~="uecm-v7-diffusion-1",return,end
p=piece.Prepared;if ~isfield(p,'Input')||p.Type~=q.Type,return,end
% Moving a dataset keeps the source filename; do not conflate separate copies.
[~,oldName,oldExt]=fileparts(string(p.Input.File));[~,newName,newExt]=fileparts(string(q.Input.File));
if oldName+oldExt~=newName+newExt,return,end
% Fits depend on normalized signals and grouping, not file location or condition labels.
% The current prepared conditions are reapplied by mergeFittingPieces.
if p.Input.Synthetic~=q.Input.Synthetic,return,end
cols=["source","cell","test","spectrum"];
if q.Type=="EIS",cols=[cols,"frequency","real","imag"];
else,cols=[cols,"time","current","voltage"];end
if ~all(ismember(cols,string(p.Data.Properties.VariableNames)))||~all(ismember(cols,string(q.Data.Properties.VariableNames))),return,end
if ~isequaln(p.Data(:,cellstr(cols)),q.Data(:,cellstr(cols))),return,end
if checkOptions&&~isequaln(uecm.fitConfiguration(p.Input.Settings),uecm.fitConfiguration(q.Input.Settings)),return,end
match=true;
end
