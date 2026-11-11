function info=variableColumnInfo(M)
%VARIABLECOLUMNINFO Classify full columns for the CSV header selection view.
names=string(M.Properties.VariableNames(:));kind=strings(size(names));known=zeros(size(names));reason=strings(size(names));
for k=1:numel(names)
 try,[v,~,kind(k)]=uecm.customColumnValues(M.(names(k)));known(k)=nnz(isfinite(v));
 catch ex,kind(k)="추가 불가";reason(k)=string(ex.message);end
end
info=table(names,kind,known,reason,'VariableNames',{'column','kind','known_rows','reason'});
end
