# game-sync

Private Origin repository for a **Godot 4** game that you can work on from a Windows home PC, a laptop, and a phone. Cloud Agents run Godot **headless** on Linux. Real playtesting stays in the Godot editor on the home machine.

Repo: [https://cursor.com/codebase/carlos-tovar/game-sync](https://cursor.com/codebase/carlos-tovar/game-sync)  
Visibility: **Private**. Change it in settings on that page if you want.

This tree currently includes a small placeholder project so Cloud Agents can run `godot --headless --import` before you copy the real game in.

## What you need

- A paid Cursor plan (Cloud Agents, iOS app, and [cursor.com/agents](https://cursor.com/agents) on Android).
- Cursor desktop on the home PC and laptop, updated to the latest version (**Help → Check for Updates**). Remote Control of the home PC (optional) needs **3.9.8+**.
- **Privacy Mode** (not Privacy Mode Legacy). Cloud Agents cannot start on Legacy. Cursor does not train on your code.
- Origin CLI on macOS, Linux, or **WSL**. It is not available in PowerShell. Docs: [https://cursor.com/docs/origin/cli](https://cursor.com/docs/origin/cli)

## Get the repository on the Windows home PC

Desktop OS is Windows. Origin CLI is **not** a PowerShell command. If you see `sh : The term 'sh' is not recognized`, you are still in PowerShell (`PS C:\Users\...>`). Leave that window and use WSL.

**1. Open WSL from PowerShell** (this is the only Origin command that belongs in PowerShell):

```powershell
wsl
```

The prompt should change to a Linux shell (`user@pc:~$`), not `PS C:\...`. If `wsl` is missing, install it in **Windows PowerShell as Administrator**, reboot, then open Ubuntu from the Start menu:

```powershell
wsl --install
```

**2. Inside WSL**, install Origin and clone:

```bash
# Run in WSL (Origin CLI is not available in PowerShell)
# Install the Origin CLI
curl -fsSL https://downloads.cursor.com/origin/install.sh | sh

# Sign in (also sets up git credentials)
origin auth login

# Clone the repository
origin repo clone carlos-tovar/game-sync
```

If `origin` is not found after install, persist `~/.local/bin` on PATH in WSL (bash), or run `scripts/ensure-origin-path.sh` after the clone exists:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Later, from PowerShell you can jump into that WSL setup with `scripts/setup-windows.ps1` instead of piping to `sh`.

**3. After clone**, import the Godot game from Windows (WSL, not PowerShell):

```bash
export PATH="$HOME/.local/bin:$PATH"
cd ~/game-sync
git pull
chmod +x scripts/import-local-godot.sh
./scripts/import-local-godot.sh --push "/mnt/c/Users/carlo/OneDrive/Desktop/Projects/Boss Game"
```

Use **Boss Game** (singular). Do not import `Boss Game Backup`. Open `~/game-sync` in Cursor and in the Godot editor afterward.

## Upgrade Cursor for this workflow

On the **home PC** and **laptop**:

- Update Cursor to the latest client.
- Confirm you can start a Cloud Agent against `carlos-tovar/game-sync` from the Agents Window.
- **Origin** is what Cursor Agents use. **GitHub** is an optional public/private mirror so people without Cursor can clone. See [GitHub mirror](#github-mirror) below.
- Indexing already ignores `.godot/` via `.cursorignore`.

On **phone**:

- iPhone / iPad: [Cursor for iOS](https://apps.apple.com/app/cursor/id6767085653) (iOS / iPadOS 26+). Direct agents and review PRs. There is no editor or terminal on mobile.
- Android: Chrome → [cursor.com/agents](https://cursor.com/agents) → Add to Home Screen. There is no native Android app yet.

## Daily loop

| Where | What you do |
| --- | --- |
| Home PC | Cursor + Godot editor. In WSL: `git pull`, playtest, `./scripts/push-both.sh`. |
| Laptop | Same Origin clone in Cursor, or start a Cloud Agent from the Agents Window / [cursor.com/agents](https://cursor.com/agents). |
| Phone | Start, follow, review, and merge that Cloud Agent. No local Godot. |

Agents should prove changes with `./scripts/verify-headless.sh`. After a laptop or phone agent opens a PR, pull on the home PC and playtest in the editor.

Cloud VMs usually have no GPU. Headless import and script checks are the bar in the cloud. Feel, animation, and input are checked at home.

Optional later: keep the home PC awake and use **Remote Control** (Settings → Agents, `/remote-control`) so an agent can use the local Godot editor without a push. The home PC must stay online.

## Commands

```bash
./scripts/cloud-agent-install.sh   # download Godot, symlink `godot`, import
./scripts/verify-headless.sh       # import + tools/ci_check.gd
./scripts/push-both.sh             # git push to Origin and GitHub
./scripts/setup-github-remote.sh carlostovar1995/game-sync
```

See [AGENTS.md](AGENTS.md) for agent-facing conventions.

## GitHub mirror

Cursor Cloud Agents keep using Origin. GitHub is a second copy for sharing with people who are not on Cursor.

GitHub **rejects files over 100MB**. This repo does not track the Godot Windows editor or the huge source zips under `assets/_incoming/` (the extracted models are already in `assets/`). Download Godot from [godotengine.org](https://godotengine.org/download).

**Once, in Ubuntu (`~/game-sync`):**

1. Create an empty repo on [github.com/new](https://github.com/new) named `game-sync` (private is fine, **no** README).
2. Sign GitHub into WSL (browser login):

```bash
gh auth login
```

If `gh` is missing: `sudo apt update && sudo apt install -y gh`, or install from [cli.github.com](https://cli.github.com/).

3. Point this clone at that repo and push:

```bash
cd ~/game-sync
git pull
chmod +x scripts/setup-github-remote.sh scripts/push-both.sh
./scripts/setup-github-remote.sh carlostovar1995/game-sync
```

After that, `./scripts/push-both.sh` updates Origin and GitHub together. Collaborators clone `https://github.com/carlostovar1995/game-sync.git` — they do not need Cursor.

If `git pull` says your branch has diverged after a history cleanup, run `git fetch origin && git reset --hard origin/main` in `~/game-sync` (only if you have no uncommitted work).

## License

Private project. All rights reserved unless you add a license.
