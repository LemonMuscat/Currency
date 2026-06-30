# Release Notes for Maintainers

This file is for the repository maintainer.

## Create a Test Release Zip

```sh
./scripts/build_app.sh
cd build
zip -r CurrencyPanel.zip CurrencyPanel.app
```

Upload `build/CurrencyPanel.zip` to GitHub Releases.

## GitHub Release Flow

1. Open `https://github.com/LemonMuscat/Currency/releases`.
2. Click **Draft a new release**.
3. Create a tag such as `v0.1.0`.
4. Add a short release title, for example `CurrencyPanel v0.1.0`.
5. Upload `CurrencyPanel.zip`.
6. Publish the release.

## macOS Gatekeeper

Without Apple Developer ID signing and notarization, users may see a macOS security warning.

For a polished public release, sign and notarize the app before uploading it.

