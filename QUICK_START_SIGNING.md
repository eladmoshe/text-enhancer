# Quick Start: Persistent Accessibility Permissions

**Problem**: Accessibility permissions reset after every rebuild  
**Solution**: Code signing makes permissions persist across rebuilds

## 5-Minute Setup

### 1. Create Certificate (One-time)
```bash
# Open Xcode → Preferences → Accounts → Manage Certificates → + → Apple Development
```

### 2. Find Certificate Name
```bash
make check-sign
# Look for: "Apple Development: Your Name (TEAMID)"
```

### 3. Set Environment Variable
```bash
export SIGN_ID="Apple Development: Your Name (TEAMID)"

# Make it permanent (optional):
echo 'export SIGN_ID="Apple Development: Your Name (TEAMID)"' >> ~/.zshrc
```

### 4. Build & Install Signed Version
```bash
./build.sh --bundle-signed
```

### 5. Grant Permissions (One Time Only!)
- App opens automatically
- Click "Open System Preferences" when prompted
- Enable TextEnhancer in Accessibility settings
- **Done!** Permissions now persist across rebuilds

## Quick Commands

| Command | Purpose |
|---------|---------|
| `./build.sh --bundle-signed` | Build signed version (persistent permissions) |
| `./build.sh --bundle` | Build unsigned version (permissions reset) |
| `./build.sh --status` | Check installation and signing status |
| `make check-sign` | Show available certificates |

## Verification

After setup, rebuilding should work without permission prompts:
```bash
./build.sh --bundle-signed  # Rebuild
# App should work immediately without new permission requests
```

## Troubleshooting

**"No certificates found"** → Create development certificate in Xcode  
**"SIGN_ID not set"** → Export your certificate name  
**Permissions still reset** → Use `--bundle-signed` not `--bundle`

📖 **Full guide**: [docs/ACCESSIBILITY_PERMISSIONS.md](docs/ACCESSIBILITY_PERMISSIONS.md) 