# Ashenwake

Godot 4.7 arena fighter (5vBoss, League-style controls). Daily work is a **local Windows or laptop clone**. GitHub is the only remote you need.

Repo: [https://github.com/carlostovar1995/ashenwake](https://github.com/carlostovar1995/ashenwake)

Home PC folder: `C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake`

## What you need

- Git for Windows and a GitHub login (`gh auth login` or Git Credential Manager).
- Godot **4.7.2** (same as `.godot-version`).
- Cursor on the machine you are editing on.

## Home PC

1. Open `C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake` in Cursor and in Godot.
2. Edit and playtest here.
3. When you are done:

```powershell
cd C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake
git add -A
git commit -m "Describe the session"
git push origin main
```

Or double-click **Sync Ashenwake** on the desktop (pull, commit if dirty, push).

Install or refresh that icon from PowerShell:

```powershell
cd C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\install-desktop-shortcut.ps1
```

## Laptop

```powershell
git clone https://github.com/carlostovar1995/ashenwake.git
```

Open the cloned folder in Cursor and Godot. `git pull` / `git push` against the same GitHub repo. No WSL.

If you already cloned the old `game-sync` URL:

```powershell
git remote set-url origin https://github.com/carlostovar1995/ashenwake.git
git pull origin main
```

## Do not

- Edit the old Ubuntu copy (`~/game-sync` or `\\wsl$\...`). It is stale.
- Commit `.godot/` or export binaries.
- Use Origin / `push-both.sh` for the daily loop.

Optional Cloud Agent scripts are still in `scripts/` if you want them later. They are not part of day-to-day work.

## License

Private project. All rights reserved unless you add a license.
