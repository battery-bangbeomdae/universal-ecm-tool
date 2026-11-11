function messages=cancelForClose(futures)
%CANCELFORCLOSE Best-effort cancellation of owned work; never wait for completion.
messages=strings(0,1);
for k=1:numel(futures)
    future=futures{k};
    try
        if ~isempty(future)&&isvalid(future),cancel(future);end
    catch ex
        messages(end+1,1)=string(ex.identifier)+": "+string(ex.message); %#ok<AGROW>
    end
end
end
