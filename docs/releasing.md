# Releasing Nelyr

Public macOS downloads must use a Developer ID Application certificate and
Apple notarization. An Apple Development signature is suitable for local
development, but it will not give downloaded builds a clean Gatekeeper
experience on other Macs.

## One-time setup

1. Add a `Developer ID Application` certificate and its private key to the
   login keychain.
2. Store App Store Connect credentials in the keychain:

   ```sh
   xcrun notarytool store-credentials NelyrNotary
   ```

3. Keep certificates, private keys, and App Store Connect credentials outside
   this repository.

## Build and package

Build the app with the distribution identity:

```sh
NELYR_DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
NELYR_SIGN_IDENTITY="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)" \
  ./scripts/build-signed-app.sh
```

Create, sign, submit, staple, and validate the DMG:

```sh
NELYR_DISTRIBUTION_IDENTITY="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)" \
NELYR_NOTARY_PROFILE="NelyrNotary" \
  ./scripts/package-dmg.sh
```

The script refuses to create a public release artifact without both the
Developer ID identity and notary profile. For layout testing only:

```sh
NELYR_ALLOW_UNNOTARIZED=1 ./scripts/package-dmg.sh
```

Never upload that preview artifact to GitHub Releases.
