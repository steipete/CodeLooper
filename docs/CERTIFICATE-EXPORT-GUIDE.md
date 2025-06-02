# Developer ID Certificate Export Guide

## Finding Your Developer ID Application Certificate

Your Keychain Access is currently showing only Apple Development certificates. To find your Developer ID Application certificate:

### 1. Check All Keychains
- In Keychain Access, look at the left sidebar
- Check both "login" and "System" keychains
- The Developer ID certificate might be in System keychain

### 2. Change Category Filter
- In the left sidebar under "Category", you're currently viewing "My Certificates"
- Try clicking on "Certificates" (without "My") to see all certificates
- Or click "All Items" to see everything

### 3. Use Search
- Use the search box in the top right
- Search for "Developer ID" or "Developer ID Application"
- Make sure "All Items" is selected in the scope

### 4. Check Certificate Trust
- If you find the certificate but it appears untrusted (red X)
- Double-click it and expand "Trust" section
- Set to "Always Trust" or "Use System Defaults"

## Proper Export Process

Once you find the Developer ID Application certificate:

1. **Expand the Certificate**
   - Click the arrow next to the certificate to show the private key
   - You should see both the certificate AND its private key

2. **Select BOTH Items**
   - Click on the certificate
   - Hold Cmd and click on the private key
   - Both should be highlighted

3. **Export as P12**
   - Right-click on the selected items
   - Choose "Export 2 items..."
   - Save as .p12 format
   - Set a strong password (this will be your MACOS_SIGNING_CERTIFICATE_PASSWORD)

4. **Verify the Export**
   ```bash
   # Check that the P12 contains both certificate and private key
   openssl pkcs12 -in your-certificate.p12 -info -noout
   # You should see lines mentioning both "Certificate" and "Private Key"
   ```

5. **Convert to Base64 for GitHub**
   ```bash
   base64 -i your-certificate.p12 | pbcopy
   # This copies the base64 string to clipboard
   ```

## Common Issues

### Certificate Not Visible
- It might be expired (check "Show Expired Certificates" in View menu)
- It might be in System keychain instead of login
- Try refreshing Keychain Access (Cmd+R)

### Certificate Without Private Key
- This happens if the certificate was imported without its key
- You'll need to re-download from Apple Developer portal
- Or restore from a backup that includes the private key

### Multiple Developer Certificates
- Look for the one that says "Developer ID Application: [Your Name/Company]"
- NOT "Apple Development: [Your Email]"
- NOT "Mac Developer: [Your Name]"

## Next Steps

After successful export:
1. Update GitHub secret `MACOS_SIGNING_CERTIFICATE_P12_BASE64` with the base64 string
2. Ensure `MACOS_SIGNING_CERTIFICATE_PASSWORD` matches the password you set
3. The CI should then be able to import and use the certificate for signing