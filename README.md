# CurrencyPanel

macOS에서 항상 띄워두고 보는 작은 환율 패널입니다.

## 기능

- 1달러, 100엔, 1위안의 원화 가격 표시
- 계산 줄의 통화를 드롭다운으로 바꾸고, 아무 칸이나 입력하면 나머지 통화 자동 변환
- 5분마다 환율 자동 갱신
- 이전 갱신값 대비 변화율 표시
- 작은 플로팅 윈도우로 다른 창 위에 유지
- 숫자 칸에서 `Cmd+A`, `Cmd+C`, `Tab`, `Shift+Tab`, `Esc` 지원
- macOS 앱 아이콘 포함

환율은 Naver 모바일 증권의 하나은행 고시 환율을 우선 사용합니다.
Naver 호출이 실패하면 Yahoo Finance를 재시도하고, 그래도 실패할 때만 ExchangeRate-API open endpoint를 예비 소스로 사용합니다.

## 앱 번들 만들기

```sh
./scripts/build_app.sh
```

완성된 앱은 `build/CurrencyPanel.app`에 만들어집니다.
현재 빌드는 작은 런처가 같은 앱 번들 안의 `CurrencyPanelRuntime`을 별도 프로세스로 띄우는 구조입니다.

## 실행

```sh
open build/CurrencyPanel.app
```

## 배포

가볍게 공유하려면 `build/CurrencyPanel.app`을 zip으로 압축해 전달할 수 있습니다.
일반 사용자가 보안 경고를 덜 보게 하려면 Apple Developer ID 서명과 notarization이 필요합니다.
