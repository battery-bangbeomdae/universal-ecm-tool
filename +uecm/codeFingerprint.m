function h = codeFingerprint(folder)
%CODEFINGERPRINT Code-version fingerprint of the +uecm package (CRC-32 per file, then of the list; no Java needed).
%   h = uecm.codeFingerprint()      % e.g. "3fa9c2d1-96files"
% Same rule as validate_holdout: results that carry this value can be traced to the exact code that made them.
if nargin<1,folder=fileparts(mfilename('fullpath'));end
h=hashCode(string(folder));
end

function h=hashCode(folder)
% Code-version fingerprint without Java (R2026b ships no JVM): CRC-32 of every +uecm .m file (sorted by
% relative path), then CRC-32 of that list. Not a security hash; it only tells code versions apart.
f=dir(fullfile(folder,'**','*.m'));full=string(fullfile({f.folder},{f.name}));[full,o]=sort(full);f=f(o);
tbl=crcTable();parts=strings(numel(f),1);
for k=1:numel(f)
    fid=fopen(full(k),'r');b=fread(fid,Inf,'*uint8');fclose(fid);
    parts(k)=extractAfter(full(k),strlength(string(folder)))+":"+string(dec2hex(crc32(b,tbl),8));
end
h=lower(string(dec2hex(crc32(unicode2native(char(join(parts,newline)),'UTF-8'),tbl),8)))+"-"+numel(f)+"files";
end

function c=crc32(b,tbl)
c=uint32(4294967295);b=uint32(b(:));
for i=1:numel(b),c=bitxor(tbl(bitand(bitxor(c,b(i)),uint32(255))+1),bitshift(c,-8));end
c=bitxor(c,uint32(4294967295));
end

function t=crcTable()
t=zeros(256,1,'uint32');
for n=0:255
    c=uint32(n);
    for k=1:8
        if bitand(c,uint32(1)),c=bitxor(uint32(3988292384),bitshift(c,-1));else,c=bitshift(c,-1);end
    end
    t(n+1)=c;
end
end

