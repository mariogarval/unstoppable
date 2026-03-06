---
name: testflight-release
description: Archive, export, and upload the Unstoppable iOS app to TestFlight from CLI. Use when asked to prepare a TestFlight build, export an IPA, or upload a release build to App Store Connect for this repository.
---

# TestFlight Release

Use this skill for CLI-based TestFlight releases of the `Unstoppable` app.

## Workflow

1. Confirm signing and archive viability.
2. Run the archive script:
   `scripts/testflight/archive_app.sh`
3. Export the IPA:
   `scripts/testflight/export_ipa.sh`
4. Upload the IPA:
   `scripts/testflight/upload_ipa.sh`

For one-shot execution, run:

```bash
scripts/testflight/release_to_testflight.sh
```

## Required Environment

The upload step requires App Store Connect API key authentication:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_PATH` (optional if the key lives in `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`)

The upload script sets `API_PRIVATE_KEYS_DIR` from `APP_STORE_CONNECT_API_KEY_PATH` so `xcrun altool` can locate the `.p8` file.

## Notes

- Archive path defaults to `build/Unstoppable.xcarchive`.
- Export path defaults to `build/testflight-export`.
- Export uses `scripts/testflight/ExportOptions.plist`.
- If export fails with missing profiles, rerun using the provided script because it includes `-allowProvisioningUpdates`.
