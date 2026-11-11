function kk = linKK(freq, re, im, opts)
%LINKK Kramers-Kronig consistency test of one impedance spectrum (Lin-KK, Schönleber et al., Electrochim. Acta 131 (2014) 20-27).
%   kk = uecm.linKK(f_Hz, Zre_Ohm, Zim_Ohm)          % Zim SIGNED (capacitive < 0), as inside the tool
%   kk = uecm.linKK(f, re, im, struct('Limit',0.02))
% Advisory only: passing is not proof of physical validity or parameter identifiability.
% Why: a spectrum that is not linear, causal and stationary (drifting SOC/temperature, cable/contact artefacts)
% violates the Kramers-Kronig relations. Fitting an ECM to it still returns numbers, but they are not physical.
% Running this BEFORE trusting a fit tells the researcher which spectra to re-measure, instead of discovering it
% after a full parameter map has been built.
% Method: Z(w) = R0 + sum_k R_k/(1+j*w*tau_k) + j*w*L, tau_k log-spaced over 1/w_max..1/w_min, linear least squares
% weighted by 1/|Z|. M = max(M_mu, M_min): M_mu is the first M with mu = 1 - sum|R_k<0|/sum|R_k>=0| < 0.85 (over-fit
% guard of the paper); M_min = 3.5 elements per decade, because a sharp single RC needs that density - with M_mu
% alone an ideal 2RC circuit left 4 % residual (checked 2026-11-09: clean 0.03 %, 0.3 % noise 0.74 %, 8 % SOC drift
% below 1 Hz 1.8 % -> review). Residuals are relative to |Z|.
% Output fields: Status "pass" | "review" | "not_run", MaxResidual (fraction), M, Mu, ResidualReal/Imag (per point),
% BadFrequencies (Hz, |residual| > Limit), Reason.
arguments
    freq double
    re double
    im double
    opts (1,1) struct = struct()
end
if ~isfield(opts,'Limit'),opts.Limit=0.01;end          % 1 % of |Z|: usual acceptance level in EIS literature
if ~isfield(opts,'MuCrit'),opts.MuCrit=0.85;end
f=freq(:);z=re(:)+1i*im(:);ok=isfinite(f)&f>0&isfinite(z)&abs(z)>0;f=f(ok);z=z(ok);
kk=struct('Status',"not_run",'MaxResidual',NaN,'M',0,'Mu',NaN,'ResidualReal',[],'ResidualImag',[], ...
    'Frequency',f,'BadFrequencies',zeros(0,1),'Limit',opts.Limit,'Reason',"");
if numel(f)<8,kk.Reason="점이 8개 미만이라 KK 검사를 하지 않았습니다.";return,end
w=2*pi*f;wt=1./abs(z);Mmax=min(floor(numel(f)/2),60);
Mmin=min(ceil(3.5*log10(max(w)/min(w))),Mmax);Mmu=Mmax;
for M=1:Mmax
    [~,mu]=solve(M);
    if mu<opts.MuCrit,Mmu=M;break,end
end
M=min(max(Mmin,Mmu),Mmax);[x,mu,A]=solve(M);
zf=A*x;rr=(real(z)-real(zf))./abs(z);ri=(imag(z)-imag(zf))./abs(z);
kk.M=M;kk.Mu=mu;kk.ResidualReal=rr;kk.ResidualImag=ri;kk.MaxResidual=max(max(abs(rr)),max(abs(ri)));
bad=abs(rr)>opts.Limit|abs(ri)>opts.Limit;kk.BadFrequencies=f(bad);
if kk.MaxResidual<=opts.Limit
    kk.Status="pass";kk.Reason=sprintf("KK 잔차 최대 %.2f%% (기준 %.1f%%, RC %d개).",100*kk.MaxResidual,100*opts.Limit,M);
else
    kk.Status="review";
    kk.Reason=sprintf("KK 잔차 최대 %.2f%%가 기준 %.1f%%를 넘습니다(%d점, %.3g~%.3g Hz). 측정 중 SOC·온도 표류나 접촉 문제를 확인하고 재측정을 검토하세요.", ...
        100*kk.MaxResidual,100*opts.Limit,nnz(bad),min(f(bad)),max(f(bad)));
end
    function [x,mu,A]=solve(m)
        tau=logspace(log10(1/max(w)),log10(1/min(w)),m);
        A=[ones(numel(w),1), 1./(1+1i*w*tau), 1i*w];      % R0 | R_k | L
        x=([real(A);imag(A)].*[wt;wt])\([real(z);imag(z)].*[wt;wt]);Rk=x(2:end-1);
        pos=sum(abs(Rk(Rk>=0)));neg=sum(abs(Rk(Rk<0)));mu=1;if pos>0,mu=1-neg/pos;end
    end
end
