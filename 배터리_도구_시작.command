#!/bin/zsh
# Launch in a new MATLAB desktop; no existing data are modified.
export UNIVERSAL_ECM_APP="${0:A:h}"
ECM_MATLAB_BIN=""
for candidate in /Applications/MATLAB_R*.app/bin/matlab(N); do
    ECM_MATLAB_BIN="$candidate"
done
if [[ -z "$ECM_MATLAB_BIN" ]]; then
    print "MATLAB을 찾지 못했습니다. MATLAB에서 이 폴더의 START.m을 열고 실행해 주세요."
    read -k 1
    exit 1
fi
exec "$ECM_MATLAB_BIN" -desktop -r "try, cd(getenv('UNIVERSAL_ECM_APP')); addpath(getenv('UNIVERSAL_ECM_APP')); universalECM=launch_universal_ecm(); catch ex, disp(getReport(ex)); end"
