# Simulink 템플릿

`UECM_1RC.slx`, `UECM_2RC.slx`는 앱의 선택한 피팅값을 적용하기 위한 구조 템플릿입니다. 직접 열면 R·C가 미지정(NaN)입니다. 앱의 **결과 상세 → 1RC/2RC 선택 → Simulink로 열기**를 사용하세요.

Simulink 신호 모델이며 Simscape 물리 회로는 아닙니다. I(방전 +), Ubase → Vterminal, Vdrop. 각 RC 가지는 R/(R*C*s+1), 초기 분극 0. 입력 전류는 보간하지 않고 계단 유지합니다. 실제 자료의 누락값이나 OCV를 생성하지 않습니다. 열리는 모델은 새 임시 파일이며, 사용자가 다른 이름으로 저장할 수 있습니다.
