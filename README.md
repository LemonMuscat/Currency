# CurrencyPanel

macOS에서 항상 띄워두고 보는 작고 빠른 환율 패널입니다.

한국에서 자주 확인하는 `1달러`, `100엔`, `1위안`의 원화 기준 환율을 먼저 보여주고, 아래 계산기에서는 USD, KRW, JPY, CNY, EUR, THB, VND 등 여러 통화를 한 번에 변환할 수 있습니다.

![CurrencyPanel screenshot](docs/screenshot.png)

## 이런 앱입니다

CurrencyPanel은 브라우저를 열거나 포털 검색을 반복하지 않고도, 데스크톱 한쪽에 계속 띄워두고 환율을 확인하기 위한 macOS 앱입니다.

상단에는 한국에서 익숙한 방식의 핵심 환율을 고정 표시합니다.

- `1달러 = 원`
- `100엔 = 원`
- `1위안 = 원`

아래 계산기에서는 아무 통화 칸에나 숫자를 입력하면 나머지 통화가 동시에 바뀝니다. 예를 들어 USD에 `100`을 입력하면 KRW, JPY, CNY, EUR, THB, VND가 한 번에 계산됩니다. 반대로 KRW나 JPY 칸에 직접 입력해도 나머지 값이 자동으로 다시 계산됩니다.

## 주요 기능

- Naver 모바일 증권의 하나은행 고시 환율 우선 사용
- 5분마다 자동 갱신
- 수동 새로고침 버튼
- `1달러`, `100엔`, `1위안` 원화 환율 고정 표시
- 여러 통화를 동시에 변환하는 계산기
- 계산기 통화 드롭다운 변경
- 이전 갱신값 대비 변화율 표시
- 숫자 칸 `Cmd+A`, `Cmd+C`, `Cmd+V`, `Tab`, `Shift+Tab`, `Esc` 지원
- macOS용 작은 플로팅 윈도우
- 앱 아이콘 포함

## 환율 데이터

기본 환율 데이터는 Naver 모바일 증권의 하나은행 고시 환율을 사용합니다.

데이터 소스 우선순위는 다음과 같습니다.

1. Naver 모바일 증권 하나은행 고시 환율
2. Yahoo Finance
3. ExchangeRate-API open endpoint

상단 핵심 환율과 아래 계산기는 같은 환율 스냅샷을 사용하도록 맞춰져 있습니다.

## 빌드

Xcode 프로젝트 없이 Command Line Tools와 AppKit으로 빌드합니다.

```sh
./scripts/build_app.sh
```

완성된 앱은 다음 위치에 만들어집니다.

```text
build/CurrencyPanel.app
```

## 실행

```sh
open build/CurrencyPanel.app
```

## 다른 Mac에서 사용하기

저장소를 받은 뒤 빌드하면 됩니다.

```sh
git clone https://github.com/LemonMuscat/Currency.git
cd Currency
./scripts/build_app.sh
open build/CurrencyPanel.app
```

## 배포

가볍게 공유하려면 `build/CurrencyPanel.app`을 zip으로 압축해 전달할 수 있습니다.

일반 사용자에게 보안 경고를 줄여 배포하려면 Apple Developer ID 서명과 notarization이 필요합니다.

## 참고

현재 앱은 작은 런처가 같은 앱 번들 안의 `CurrencyPanelRuntime`을 별도 프로세스로 띄우는 구조입니다. 창 관리 앱과의 호환성을 위해 실제 런타임은 앱 번들 내부의 고정 경로에서 실행됩니다.
