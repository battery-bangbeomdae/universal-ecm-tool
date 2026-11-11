function pieces=readFitCaches(parts,roots,signature)
%READFITCACHES Stream each root once; retain only validated per-input results.
% No disk index, cache rewrite, deletion, or persistent archive retention.
pieces=cell(size(parts));names=strings(size(parts));
for k=1:numel(parts)
 [~,name,ext]=fileparts(string(parts{k}.Input.File));names(k)=name+ext;
end
for root=reshape(unique(roots(strlength(roots)>0),'stable'),1,[])
 if ~isfolder(root),continue,end
 targets=find(roots==root);candidates=dir(fullfile(root,'**','fit_*.mat'));
 [~,order]=sortrows(table([candidates.datenum]',string({candidates.name})'));
 previousSignature=[];previousCompatible=false;
 for n=reshape(order,1,[])
  try
   path=fullfile(candidates(n).folder,candidates(n).name);
   header=load(path,'signature');
   if isequal(header.signature,previousSignature),compatible=previousCompatible;
   else,compatible=uecm.fitSignatureMatches(header.signature,signature);previousSignature=header.signature;previousCompatible=compatible;end
   if ~compatible,continue,end
   saved=load(path,'bundle');archive=saved.bundle;
   [~,name,ext]=fileparts(string(archive.Prepared.Input.File));eligible=targets(names(targets)==name+ext);
   for k=reshape(eligible,1,[])
    if uecm.fitArchiveMatches(archive,parts{k}),pieces{k}=uecm.mergeEISArchives(pieces{k},archive);end
   end
   clear saved archive
  catch
   % Keep the established behavior: corrupt/incompatible archives are ignored.
  end
 end
end
end
