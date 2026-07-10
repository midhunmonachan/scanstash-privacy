# ScanStash Privacy Policy Site

Static, JavaScript-free privacy policy for the ScanStash Android app.

## Local Verification

```powershell
npm install
npm test
```

The test runs structural policy checks and Playwright layout verification at desktop and true `390x844` mobile viewports. QA screenshots are written to `.qa` and excluded from Git.

Verify the deployed GitHub Pages site and its dependencies with:

```powershell
.\scripts\verify-live-site.ps1
```

## Planned GitHub Pages URL

`https://midhunmonachan.github.io/scanstash-privacy/`

Publish from the `main` branch repository root. The public repository is intentionally separate from the private Android source repository.

## Policy Contact

Privacy inquiries use the public repository's GitHub Issues page. The Google Play developer and app-support email must still be configured and verified separately in Play Console.
