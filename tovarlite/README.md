# TovarLite portable auto-update

TovarLite was launching a frozen `client-1.12.37-SNAPSHOT` jar, so it showed
**out of date** after Old School / RuneLite updates.

On every start it now downloads the official `RuneLite.jar` launcher if a
newer GitHub release exists. That launcher then pulls the current client from
`https://static.runelite.net/bootstrap.json`.

The shaded jar in a zip is only an offline fallback.

## Patch the copy you already launch

Your shortcut points at:

`C:\Users\carlo\OneDrive\Desktop\Projects\Runtelite - Dev\distribution\out\TovarLite-Portable\TovarLite.vbs`

From this repo:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tovarlite\Install-TovarLiteAutoUpdate.ps1 `
  -PortableRoot "C:\Users\carlo\OneDrive\Desktop\Projects\Runtelite - Dev\distribution\out\TovarLite-Portable"
```

Then double-click `TovarLite.vbs` as usual. The first launch downloads
`RuneLite.jar` (~2.5 MB) and the current client into
`%USERPROFILE%\.runelite\repository2`. After that, each start checks for
updates before the client opens.

If `Runtelite - Dev` is a git checkout of this tree, you can instead copy
`tovarlite\portable\*` over `distribution\out\TovarLite-Portable\` (keep
`App\jre`, the shaded jar, `logo.ico`, and `bundled-dot-runelite`).

Set `TOVARLITE_SKIP_UPDATE=1` to skip refreshing `RuneLite.jar`. The official
launcher still updates the game client when that jar is already present.

## Layout

- `portable/` — scripts copied into a TovarLite-Portable folder
- `scripts/` — freshness helpers used by `Play.bat` from a git checkout
- `tests/` — version and download checks (`python3 tovarlite/tests/test_update_tovarlite.py`)
