function [message,missing]=coverageMessage(C)
%COVERAGEMESSAGE Warn about recognition gaps, without blocking valid fitting.
mask=C.missing_groups>0|C.partial_groups>0|C.measurement_groups==0;missing=any(mask);
message="축·용량 정보가 모든 측정 그룹에 연결됐습니다. 값의 정확성이나 다른 가공 경로와의 일치 검증을 뜻하지는 않습니다.";
if missing
 message="축·용량 정보 미연결: "+join(unique(C.label(mask),'stable'),", ")+ ...
    ". 원본에 없다는 뜻은 아닙니다. ‘축 정보 점검’에서 확인·보완하세요. 미연결 조건 없이도 신호 피팅은 가능합니다.";
end
end
