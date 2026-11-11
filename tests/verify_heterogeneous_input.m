function verify_heterogeneous_input()
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
out=fullfile(root,'validation_multi_input_20261106');if ~isfolder(out),mkdir(out);end
a=fullfile(out,'signed_eis.csv');b=fullfile(out,'negative_imag_eis.csv');
src=uecm.readInput(string(fullfile(root,'examples','SYNTHETIC_eis_practice.csv')));
T=src.Data;im=src.Mapping.imag;assert(strlength(im)>0);
writetable(T,a);
T.(im)=-T.(im);T=renamevars(T,im,'neg_im_z_ohm');T.extra_note=repmat("different schema",height(T),1);writetable(T,b);
o=uecm.defaults();o.Circuit="RC";
batch=uecm.readInputs([string(a);string(b)],o,"");p=uecm.prepare(batch);
assert(~p.Blocked);n=height(src.Data);
assert(max(abs(p.Data.imag(1:n)-p.Data.imag(n+1:end)))<1e-12);
single=uecm.analyze(uecm.readInput(string(a),o));both=uecm.analyze(batch);
assert(numel(both.Fits)==2*numel(single.Fits)&&~isempty(both.Fits));
assert(numel(unique(string(cellfun(@(f)f.SourceFile,both.Fits,'UniformOutput',false))))==2);
saved=uecm.exportBundle(both,string(out));
reopened=uecm.Models.SessionModel.loadFile(string(fullfile(saved,'session.mat')),o,"");
assert(numel(reopened.Bundle.Prepared.Input.Files)==2);
assert(~uecm.prepare(reopened.Bundle.Prepared.Input).Blocked);
disp('HETEROGENEOUS_INPUT_CHECKS_PASSED');
end
