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

If `origin` is not found after install, persist `~/.local/bin` on PATH in WSL (bash):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Then:

1. In Godot on the home PC: **Project → Version Control → Generate Version Control Metadata** (if the game does not already have `.gitignore` / `.gitattributes`).
2. Copy `project.godot`, `scenes/`, `scripts/`, and assets into the clone. Keep `.godot/` out of git. Do not delete this repo’s `.cursor/`, `scripts/`, `AGENTS.md`, `.godot-version`, or `tools/ci_check.gd`.
3. Set `.godot-version` to the same tag as the home editor (example: `4.7-stable` or `4.4.1-stable`). Match `config/features` in `project.godot`.
4. If art or audio files are huge, enable Git LFS before the first large commit.
5. Commit and `git push`.
6. Open the clone in Cursor (WSL path or a synced Windows folder). Do not force-push import caches.

## Upgrade Cursor for this workflow

On the **home PC** and **laptop**:

- Update Cursor to the latest client.
- Confirm you can start a Cloud Agent against `carlos-tovar/game-sync` from the Agents Window.
- You do **not** need a separate GitHub remote. This Origin repo is enough.
- Indexing already ignores `.godot/` via `.cursorignore`.

On **phone**:

- iPhone / iPad: [Cursor for iOS](https://apps.apple.com/app/cursor/id6767085653) (iOS / iPadOS 26+). Direct agents and review PRs. There is no editor or terminal on mobile.
- Android: Chrome → [cursor.com/agents](https://cursor.com/agents) → Add to Home Screen. There is no native Android app yet.

## Daily loop

| Where | What you do |
| --- | --- |
| Home PC | Cursor + Godot editor. In WSL: `git pull`, playtest, `git push`. |
| Laptop | Same Origin clone in Cursor, or start a Cloud Agent from the Agents Window / [cursor.com/agents](https://cursor.com/agents). |
| Phone | Start, follow, review, and merge that Cloud Agent. No local Godot. |

Agents should prove changes with `./scripts/verify-headless.sh`. After a laptop or phone agent opens a PR, pull on the home PC and playtest in the editor.

Cloud VMs usually have no GPU. Headless import and script checks are the bar in the cloud. Feel, animation, and input are checked at home.

Optional later: keep the home PC awake and use **Remote Control** (Settings → Agents, `/remote-control`) so an agent can use the local Godot editor without a push. The home PC must stay online.

## Commands

```bash
./scripts/cloud-agent-install.sh   # download Godot, symlink `godot`, import
./scripts/verify-headless.sh       # import + tools/ci_check.gd
```

See [AGENTS.md](AGENTS.md) for agent-facing conventions.

## License

Private project. All rights reserved unless you add a license.
