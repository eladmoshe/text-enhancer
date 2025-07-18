# TextEnhancer – Post-Certificate Signing Checklist

This document assumes you’ve already obtained a **Developer ID Application** certificate for the Lemonade team (for example `Developer ID Application: Elad Moshe (ABCD123456)`). Follow the steps below **in order** to ensure TextEnhancer is signed properly so that macOS remembers Accessibility & Screen-Recording permissions.

---
## 1  Install the certificate & key
1. Double-click the downloaded `.cer` file.
2. In **Keychain Access** choose **login** keychain when prompted.
3. Verify under *My Certificates* that you see the new identity and that it contains a private-key entry (▼ disclosure arrow shows a ➤ key icon).

> **Tip:** Export a backup (`.p12`) and store it safely (corporate password vault).

---
## 2  Update the Makefile
Open `Makefile` and either:
* replace the placeholder in the line
  ```make
  SIGN_ID ?= Developer ID Application: YOUR_NAME (TEAMID)
  ```
  with your exact certificate common-name, **or**
* keep the placeholder and export `SIGN_ID` when building:
  ```bash
  export SIGN_ID="Developer ID Application: Elad Moshe (ABCD123456)"
  ```

The Makefile already passes `--timestamp=none` and Hardened-Runtime options.

---
## 3  Clean and rebuild a signed bundle
```bash
make clean          # remove artefacts
make bundle-signed  # builds, signs, and creates TextEnhancer.app
```
> The target prints ✅ when signing succeeds.

---
## 4  Install the signed build for testing
```bash
make install        # copies bundle to ~/Applications and strips quarantine
```

---
## 5  Reset old TCC entries (one-time)
```bash
# run each line once
tccutil reset Accessibility  com.lemonadeinc.textenhancer
tccutil reset ScreenCapture com.lemonadeinc.textenhancer
```

---
## 6  First-launch permission flow
1. Quit **System Settings** if it’s open.
2. Launch `~/Applications/TextEnhancer.app`.
3. Grant Accessibility → toggle ON.
4. Trigger a screen-capture inside the app; grant Screen Recording.
5. Quit & relaunch TextEnhancer – both toggles should stay enabled.
6. Reboot the Mac and relaunch to confirm persistence.

---
## 7  Validate the signature
```bash
codesign -dv --verbose=2 ~/Applications/TextEnhancer.app | grep -E "Identifier|TeamIdentifier"
```
You should see your **TeamIdentifier** (not set → wrong).

Optional full notarisation check (needs internet):
```bash
spctl -a -vv ~/Applications/TextEnhancer.app
```

---
## 8  CI / build-server integration
* Install the `.p12` in the CI machine’s keychain and unlock it during the pipeline.
* Export `SIGN_ID` (or set it in the Makefile) before calling `make bundle-signed`.
* Keep `--timestamp=none` to avoid non-deterministic signatures.

---
## 9  Troubleshooting
| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| System Settings toggle flips OFF instantly | App was rebuilt without re-signing or signed with wrong cert | Re-run **Step 3** with correct `SIGN_ID` |
| codesign output shows `TeamIdentifier=not set` | Certificate not installed or not used | Repeat **Step 1** & **Step 2** |
| Gatekeeper “cannot be opened” warning | Quarantine attribute not removed | `xattr -d com.apple.quarantine <app>` or use `make install` |

---
## 10  Next steps
* Once validation passes on your machine, push the changes (including the updated `Makefile` and this document) and share the certificate common-name with team members.
* Everyone must follow **Step 1** (install certificate) on their dev Macs before running signed builds locally.
* Consider notarising the app for external distribution (separate process, not required for internal use). 