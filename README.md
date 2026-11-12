<p align="center">
  <img src="assets/brand/logo.png" width="140" alt="배터리 방범대 로고">
</p>

<h1 align="center">Universal_ECM_Tool</h1>

<p align="center">
  <b>배터리 시험 데이터를 넣으면 등가회로(ECM) 파라미터가 나오는 MATLAB 데스크톱 분석 도구</b><br>
  HPPC · EIS 원시 데이터 → 자동 변환 → 1RC/2RC/CPE/Warburg 피팅 → 회로도 · 2D/3D 조건 맵 · Simulink 모델
</p>

<p align="center">
  <a href="https://github.com/battery-bangbeomdae/universal-ecm-tool/releases/latest">최신 버전 다운로드</a> ·
  <a href="https://github.com/battery-bangbeomdae/universal-ecm-tool/releases/latest">사용자 매뉴얼(PDF)</a> ·
  <a href="https://github.com/battery-bangbeomdae/universal-ecm-tool/issues">문의 · 오류 신고</a>
</p>

---

## 왜 이 도구인가

계산 예제가 아니라, **실험실에서 나온 파일을 그대로 넣어 쓰는 도구**입니다.

| 연구 현장의 문제 | Universal_ECM_Tool |
|---|---|
| 장비마다 파일 형식·단위·전류 부호가 다르다 | EC-Lab(`.mpt`), Gamry(`.dta`), Arbin·Digatron·EnerWave CSV 등을 **자동 인식·변환** |
| 어떤 회로 모델이 맞는지 판단이 어렵다 | 1RC·2RC·1CPE·2CPE(±Warburg)를 한 번에 계산하고 **권장 모델과 근거**를 제시 |
| SOC·온도·SOH에 따른 변화를 한눈에 보기 어렵다 | 조건별 **2D/3D 파라미터 맵**, 여러 파일 합쳐 보기·나눠 보기 |
| 빈 조건을 임의 값으로 채워 결과가 왜곡된다 | 모르는 값은 채우지 않고 **"추가로 필요한 자료"**로 알려 줌 |
| 결과를 다시 쓰기 어렵다 | CSV 결과표, 다시 열기용 세션, **Simulink 1RC·2RC 모델**로 바로 연결 |

## 주요 기능

- **불러오기**: 파일·폴더(하위 폴더 포함) 일괄 읽기, Excel 시트 선택
- **입력 확인**: 열 연결·단위·전류 부호 확인, SOC·SOH·온도·사이클·용량 조건 연결
- **품질 검사**: EIS 유도성 영역·이상점·불안정 반복 구간 제외 및 표시, Lin-KK 일관성 진단
- **피팅**: 다중 초기값, 후보 모델 비교(RMSE·BIC), candidate / review 품질 판정
- **결과 보기**: 회로도·파라미터 표, 실측·피팅·잔차 그래프, 파일별 오차 분포
- **조건별 비교**: 피팅 없이 SOC·온도·SOH·사이클별 실측 Nyquist·펄스 응답 비교
- **저장·복구**: 결과 묶음 저장, 자동 피팅 백업, 세션 다시 열기

## 빠른 시작

**필요 환경**: MATLAB R2026b (Optimization Toolbox · Parallel Computing Toolbox 권장, Simulink 선택)

1. [Releases](https://github.com/battery-bangbeomdae/universal-ecm-tool/releases/latest)에서 `Universal_ECM_Tool_v8.1.zip`을 내려받아 압축을 풉니다.
2. MATLAB에서 `START.m`을 열고 **Run**을 누릅니다.
3. **상세 설정 · 열 연결** → **열 연결** 탭 → 예제 **실제 EIS · 공개 자료 12개** → **선택한 예제 열기**
4. **피팅 실행** → 결과 표에서 한 행 선택 → **선택 측정의 회로 · 응답**

자세한 사용법은 Releases에 함께 올린 **사용자 매뉴얼(PDF)**을 보세요. 처음 쓰는 사람도 매뉴얼 제4장 「따라 하기」만으로 첫 분석을 마칠 수 있습니다.

## 폴더 구성

```
START.m                  실행 파일
+uecm/                   프로그램 본체
config/                  단위 환산표, 공개 데이터 형식 정의
examples/                연습용 예제 (REAL_* 공개 실측, SYNTHETIC_* 가상)
templates/               입력 양식 (EIS, HPPC, 연구 패키지)
assets/simulink/         Simulink 1RC·2RC 기본 모델
tests/                   자동 검사 (MATLAB unittest)
```

## 동작 확인 범위와 한계

- 동작 확인: macOS + MATLAB R2026b. 다른 OS·버전은 확인하지 않았습니다.
- 결과는 넣은 데이터에 맞춘 **추정값**이며, 배터리 안전 판정이나 BMS 제어값으로 그대로 쓰면 안 됩니다.
- 주행 데이터 같은 일반 동적 시계열은 지원하지 않습니다.

## 예제 데이터 출처

| 파일 | 출처 | 이용 조건 |
|---|---|---|
| `examples/REAL_D010_eis_12spectra.csv` | Medina, R. et al., *Characterization, ageing and post-mortem dataset of commercial 58Ah prismatic NMC cells*, Zenodo (2026). DOI: [10.5281/zenodo.22301764](https://doi.org/10.5281/zenodo.22301764) — 일부 발췌, 측정값 무변경 | CC BY 4.0 |
| `examples/REAL_D014_hppc_one_pulse.csv` | Weng, A. et al., *Battery test data – fast formation study*, University of Michigan Deep Blue Data (2021). DOI: [10.7302/pa3f-4w30](https://doi.org/10.7302/pa3f-4w30) — 일부 발췌 | CC BY-NC 4.0 (비상업) |

`SYNTHETIC_*` 파일은 회로 수식으로 만든 연습용 데이터입니다. 시험용 제3자 데이터의 출처와 라이선스는 [tests/DATA_SOURCES.md](https://github.com/battery-bangbeomdae/universal-ecm-tool/blob/main/tests/DATA_SOURCES.md)에 있습니다.

## 라이선스

Copyright © 2026 배터리 방범대. All rights reserved.
사용 조건이 확정되기 전까지 무단 복제·재배포를 금합니다. MATLAB·Simulink는 The MathWorks, Inc.의 등록 상표이며, 이 저장소에 포함되어 있지 않습니다.

## 만든 사람들

**배터리 방범대** — KG 청년 이차전지 미래기술 아카데미 14기 F반 1조
