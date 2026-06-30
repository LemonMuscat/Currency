# CurrencyPanel

A compact macOS currency panel designed to stay open on your desktop.

CurrencyPanel shows the exchange rates Korean users most often check at a glance: **1 USD in KRW**, **100 JPY in KRW**, and **1 CNY in KRW**. It also includes a multi-currency calculator where editing any currency automatically updates all the others.

한국에서 자주 보는 `1달러`, `100엔`, `1위안` 기준 환율과 다중 통화 계산기를 한 화면에 띄워두는 macOS 앱입니다.

![CurrencyPanel screenshot](docs/screenshot.png)

## Why This App?

Most currency apps are either too large, too slow to glance at, or focused on one-off conversion. CurrencyPanel is meant to be left open all day, like a small market widget on the side of your screen.

It is especially useful if you frequently compare Korean won with USD, JPY, CNY, EUR, THB, or VND while shopping, traveling, investing, working with overseas prices, or checking international payments.

## Features

- Compact always-visible macOS floating panel
- Key KRW exchange cards:
  - `1 USD -> KRW`
  - `100 JPY -> KRW`
  - `1 CNY -> KRW`
- Multi-currency calculator
- Edit any row and all other currencies update instantly
- Default calculator currencies:
  - USD
  - KRW
  - JPY
  - CNY
  - EUR
  - THB
  - VND
- Currency selector for each calculator row
- Automatic refresh every 5 minutes
- Manual refresh button
- Change indicators compared with the previous refresh
- Keyboard-friendly input:
  - `Cmd+A` select all
  - `Cmd+C` copy
  - `Cmd+V` paste
  - `Tab` next field
  - `Shift+Tab` previous field
  - `Esc` finish editing
- macOS app icon included

## Exchange Rate Sources

CurrencyPanel prioritizes exchange rates that feel familiar to Korean users.

Source priority:

1. Naver mobile finance, Hana Bank exchange rates
2. Yahoo Finance
3. ExchangeRate-API open endpoint

The top exchange cards and the calculator use the same rate snapshot, so the values stay consistent across the app.

## Installation for Users

If a prebuilt release is available, download it from the GitHub Releases page:

```text
https://github.com/LemonMuscat/Currency/releases
```

Then:

1. Download the `.zip` or `.dmg` file.
2. Open it.
3. Move `CurrencyPanel.app` to your Applications folder if desired.
4. Launch the app.

If the app is not notarized yet, macOS may show a security warning. In that case, right-click the app and choose **Open**.

## Build From Source

This project builds a native macOS AppKit app without an Xcode project.

Requirements:

- macOS
- Xcode Command Line Tools

Build:

```sh
./scripts/build_app.sh
```

The app bundle will be created here:

```text
build/CurrencyPanel.app
```

Run:

```sh
open build/CurrencyPanel.app
```

## Clone on Another Mac

```sh
git clone https://github.com/LemonMuscat/Currency.git
cd Currency
./scripts/build_app.sh
open build/CurrencyPanel.app
```

## Why Is `build/` Not Committed?

The `build/` folder contains generated files, including `CurrencyPanel.app`.

Generated app bundles are usually **not committed to the source repository** because they can be rebuilt from the source code and may be large or platform-specific.

For end users, prebuilt apps should be distributed through **GitHub Releases**, not committed directly into the main repository.

Recommended structure:

- Repository source code: `Sources/`, `Resources/`, `scripts/`, `README.md`
- Generated local build: `build/CurrencyPanel.app`
- Public downloadable app: GitHub Releases asset, such as `CurrencyPanel.zip` or `CurrencyPanel.dmg`

## Distribution Notes

For personal sharing or testing, you can zip the app bundle:

```sh
./scripts/build_app.sh
cd build
zip -r CurrencyPanel.zip CurrencyPanel.app
```

Then upload `CurrencyPanel.zip` to GitHub Releases.

For a smoother public macOS distribution experience, the app should eventually be signed with an Apple Developer ID and notarized by Apple. Without notarization, users may need to use right-click -> Open the first time they launch it.

## Project Structure

```text
Currency/
├── Resources/
│   ├── AppIcon.icns
│   ├── AppIcon.png
│   └── Info.plist
├── Sources/
│   ├── CurrencyPanel/
│   │   └── main.m
│   └── Launcher/
│       └── main.c
├── docs/
│   └── screenshot.png
├── scripts/
│   └── build_app.sh
└── README.md
```

## Implementation Note

CurrencyPanel uses a small launcher process that starts `CurrencyPanelRuntime` from inside the same app bundle. This keeps the runtime path stable for macOS window managers while preserving the app's lightweight floating-panel behavior.
