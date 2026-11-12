# 제3자 데이터 출처 (Third-party data sources)

이 저장소의 일부 파일은 다른 기관이 공개한 실측 데이터를 발췌한 것입니다. 이 파일들은 프로젝트의 저작권 표시(All rights reserved) 대상이 아니며, 각 원 출처의 라이선스를 따릅니다. 측정값은 바꾸지 않았고, 필요한 구간만 잘라 냈습니다.

| 파일 | 제목 (Title) | 저작자 (Author) | 출처 (Source) | 라이선스 (License) | 변경 사항 |
|---|---|---|---|---|---|
| `examples/REAL_D010_eis_12spectra.csv` | Characterization, ageing and post-mortem dataset of commercial 58Ah prismatic NMC cells | Medina, R. et al. | Zenodo, https://doi.org/10.5281/zenodo.22301764 | CC BY 4.0, https://creativecommons.org/licenses/by/4.0/ | Cell_4 특성 평가 EIS 12개 스펙트럼 발췌 |
| `examples/REAL_D014_hppc_one_pulse.csv` | Battery test data – fast formation study | Weng, A.; Mohtat, P.; Attia, P.; Less, G.; Lee, S.; Stefanopoulou, A. (University of Michigan) | Deep Blue Data, https://doi.org/10.7302/pa3f-4w30 | CC BY-NC 4.0 (비상업), https://creativecommons.org/licenses/by-nc/4.0/ | HPPC 첫 방전 펄스와 앞뒤 휴지 구간 69행 발췌 |
| `tests/fixtures_raw/digatron_30T_25C_HPPC_first1100s.csv`, `tests/fixtures_raw/mcmaster_30T_25C_HPPC_first1100s.mat` | Samsung INR21700 30T 3Ah Li-ion Battery Data | Kollmeyer, P.; Skells, M. (McMaster University) | Mendeley Data, https://data.mendeley.com/datasets/9xyvy2njj3 | CC BY 4.0, https://creativecommons.org/licenses/by/4.0/ | 25 °C HPPC 시험 앞 1,100초 발췌 |
| `tests/fixtures_raw/Cell19_80SOH_15degC_05SOC_8641.mat`, `Cell24_90SOH_25degC_50SOC_8104.mat`, `Cell28_100SOH_25degC_50SOC_10000.mat`, `Cell28_100SOH_25degC_50SOC_10000.xls`, `REAL_LGM50_Cell28_SOC50_25C_EIS.csv` | DIB_Data (LG M50 셀 EIS, SOH·온도·SOC별) | Rashid, M.; Sheikh, M.; Sansom, J.; Faraji Niri, M.; Marco, J. (University of Warwick) | Mendeley Data, https://doi.org/10.17632/mn9fb7xdx6.3 | CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/ | 스펙트럼 3개 발췌, CSV는 표준 열 이름으로 변환 |
| `tests/fixtures_raw/wuppertal_50E_MCU1_REAL_excerpt_HPPC1.csv`, `tests/fixtures_raw/wuppertal_50E_MCU6_REAL_excerpt_SOC50_glitch.csv` | Samsung INR21700-50E Capacity and HPPC tests | Popp, A.; Spaeth, U.; Schmuelling, B. (University of Wuppertal) | Zenodo, https://zenodo.org/records/10891871 | CC BY-NC 4.0 (비상업), https://creativecommons.org/licenses/by-nc/4.0/ | 원본 `Batch1.7z`에서 시계열 일부 구간 발췌, 파일 이름은 팀이 바꿈 |
| `tests/fixtures_jwl_template_inputs/Molicel_P42A_Independent_EIS_conditions.csv`, `Molicel_P42A_Independent_EIS_signals.csv` | Experimental Data for Electrochemical Impedance Characterization of Li-ion Batteries Under Varying State of Charge, Current Amplitude and Rest Time | Balasubramanian, B.; Pillai, P.; Balasingam, B. (University of Windsor) | Mendeley Data, https://data.mendeley.com/datasets/dcbrc4zmc5/2 | CC BY 4.0, https://creativecommons.org/licenses/by/4.0/ | `Factor_Resttime` 폴더 EIS를 표준 템플릿(조건표 + 신호)으로 변환 |
| `tests/fixtures_jwl_template_inputs/D011_NMC532_pouch64Ah_EIS_conditions.csv`, `D011_NMC532_pouch64Ah_EIS_signals.csv` | Detailed characterization and parameterization of a large state-of-the-art commercial Li-ion pouch cell. Part 1: Cell characterization | Wind, J.; Vie, P. J. S. (Institute for Energy Technology) | Zenodo, https://doi.org/10.5281/zenodo.17746533 | CC BY 4.0, https://creativecommons.org/licenses/by/4.0/ | EIS.zip의 온도별 스펙트럼을 표준 템플릿(조건표 + 신호)으로 변환 |

## 이용 조건 요약

- CC0 1.0: 조건 없이 쓸 수 있습니다(출처 표기는 예의상 남깁니다).
- CC BY 4.0: 출처를 밝히면 상업적 이용을 포함해 자유롭게 쓸 수 있습니다.
- CC BY-NC 4.0: 출처를 밝히고 **비상업 목적**으로만 쓸 수 있습니다. Wuppertal 파일은 자동 검사용이고, D014는 무료 배포본의 예제입니다. 유료 판매본에는 두 데이터 모두 넣지 않습니다.
