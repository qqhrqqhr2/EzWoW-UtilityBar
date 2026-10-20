# Changelog - EzWoW - Utility Bar

## v0.6.0
- 드래그 시 마우스 포인터와 아이콘/프레임 좌표가 어긋나거나 벌어지는 스케일 오차(`EffectiveScale`) 및 초기 점프 현상 수정
- **모듈 구조 재설계 (`Core/`, `Data/`, `Modules/`, `UI/`) 및 스캔 속도 개선**:
  - `Core/Init.lua`, `Core/Locales.lua`, `Core/UIKit.lua`
  - `Data/ClassificationRules.lua`, `Modules/InventoryScanner.lua`
  - `UI/ToolbarFrame.lua`, `UI/OptionsWindow.lua`
  - 툴팁 기반 아이템 분류 결과 캐싱 및 `BAG_UPDATE` 이벤트 디바운싱 적용으로 가방 정리 시 연산 부하 대폭 감소
  - 슬래시 명령어 `/ezub`, `/ezwowutilitybar` 및 `EzWoW_UtilityBarDB` 정비

## v0.5.7
- **음식·물약·붕대 최고 등급만 표시** 옵션 추가 (생명력 물약, 마나 물약, 일반 음식, 음료, 버프 음식별 최고 등급 자동 선별)
- **이동(Travel)** 분류 추가 (귀환석, 탈것 아이템, 탈것 소환 주문)
- **위로 펼치기(Grow Upward)** 옵션 추가 및 전투 중 소진된 아이템 반투명 표시 지원

## v0.5.6
- 기계공학 장치 인식 보강 및 착용 중인 모든 부위의 사용 효과 장비(`Equipped Items`) 지원
- 개별 아이콘 숨기기(`x` 버튼) 및 설정창 복원 기능, 불투명도(`30~100%`) 및 마우스오버 페이드 옵션 추가
