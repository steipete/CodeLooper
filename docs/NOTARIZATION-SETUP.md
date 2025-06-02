# Notarization Setup Guide

## Your App Store Connect API Details

Based on your screenshot, here are your API credentials:

- **Issuer ID**: `69a6de84-c8a9-47e3-e053-5b8c7c11a4d1`
- **Key ID**: `3578697888`
- **Key Name**: CodeLooper

## Steps to Complete Setup:

1. **Download the P8 Key File**
   - Click the "Download" button in App Store Connect
   - Save the file (it will be named something like `AuthKey_3578697888.p8`)
   - **Important**: You can only download this file once!

2. **Read the P8 File Content**
   ```bash
   cat ~/Downloads/AuthKey_3578697888.p8
   ```
   
   It should look like:
   ```
   -----BEGIN PRIVATE KEY-----
   [multiple lines of base64 encoded content]
   -----END PRIVATE KEY-----
   ```

3. **Add to GitHub Secrets**
   Go to: https://github.com/steipete/CodeLooper/settings/secrets/actions
   
   Add or update these secrets:
   - `APP_STORE_CONNECT_API_KEY_P8`: Paste the entire content of the P8 file (including BEGIN/END lines)
   - `APP_STORE_CONNECT_KEY_ID`: `3578697888`
   - `APP_STORE_CONNECT_ISSUER_ID`: `69a6de84-c8a9-47e3-e053-5b8c7c11a4d1`

## Verifying Your Setup

Once you've added all secrets, the CI will:
1. Build your app ✅ (already working)
2. Sign it with your Developer ID ✅ (already working)
3. Submit it to Apple for notarization ⏳ (will work after P8 setup)
4. Wait for Apple to verify it
5. Create a notarized DMG

## What Notarization Does

- Removes Gatekeeper warnings
- Allows your app to run on any Mac without security prompts
- Shows users that Apple has verified your app is safe
- Required for distribution outside the Mac App Store

## Troubleshooting

If notarization fails:
- Check that the P8 file content includes the BEGIN/END lines
- Verify all three secrets are set correctly
- The API key needs "Developer" access level (which yours has ✅)