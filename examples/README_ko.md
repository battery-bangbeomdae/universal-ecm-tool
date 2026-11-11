# 예제 구분

| 파일 | 종류 | 주의점 |
|---|---|---|
| REAL_D010_eis_12spectra.csv | 공개 실험 EIS의 부분집합 | CALB Cell_4, 12 스펙트럼. 조건표 SOC/온도 연결, 측정 수치 보존 |
| REAL_D014_hppc_one_pulse.csv | 공개 시간·전류·전압의 부분집합 | Bio-Logic CA1, 69행. 충전 양수 부호. SOC 미확인. 단순 1-RC 적합성 부족한 주의 사례 |
| SYNTHETIC_eis_practice.csv | 가상 화면/수치 연습 | 실험값 아님. 회로 분석식으로 생성 |
| SYNTHETIC_hppc_practice.csv | 가상 화면/수치 연습 | 실험값 아님. 독립적인 직사각 펄스 분석식으로 생성 |
| SYNTHETIC_missing_time.csv | 시간 누락 요청 연습 | 위 가상 HPPC의 시간열을 제외한 예제 |
| template_hppc_columns_only.csv | 열 모양 설명용 가상 예시 | 이 한 줄만으로 회로를 구할 수 없음 |

원본 출처·선별 조건은 REAL_*_provenance.json, 가상 정답은 ../tests/fixture_truth.json을 따른다. 예제 값을 빈 실험 데이터에 채워 넣으면 안 된다.
