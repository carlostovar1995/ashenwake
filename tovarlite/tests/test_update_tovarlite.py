#!/usr/bin/env python3
"""Contract tests for TovarLite launch-time auto-update.

Version compare must match distribution/portable/App/Update-TovarLite.ps1.
"""
from __future__ import annotations

import json
import re
import ssl
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAY_BAT = ROOT / "portable" / "App" / "Play.bat"
UPDATE_PS1 = ROOT / "portable" / "App" / "Update-TovarLite.ps1"
UI_PS1 = ROOT / "portable" / "App" / "TovarLitePortableUI.ps1"
INSTALL_PS1 = ROOT / "Install-TovarLiteAutoUpdate.ps1"
USER_AGENT = "TovarLite-Portable-Tests (+https://github.com/carlostovar1995/runelite)"


def compare_tovarlite_version(left: str, right: str) -> int:
    def parts(version: str) -> list[int]:
        if not version or not version.strip():
            return [0]
        v = version.strip()
        if v[:1] in ("v", "V"):
            v = v[1:]
        cut = len(v)
        for i, ch in enumerate(v):
            if ch in "-+":
                cut = i
                break
        v = v[:cut]
        out: list[int] = []
        for piece in v.split("."):
            digits = re.sub(r"[^0-9]", "", piece)
            out.append(int(digits) if digits else 0)
        return out or [0]

    a, b = parts(left), parts(right)
    n = max(len(a), len(b))
    a += [0] * (n - len(a))
    b += [0] * (n - len(b))
    for av, bv in zip(a, b):
        if av > bv:
            return 1
        if av < bv:
            return -1
    return 0


def fetch_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    ctx = ssl.create_default_context()
    with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def test_version_compare_contract() -> None:
    cases = [
        ("1.13.1", "1.12.37-SNAPSHOT", 1),
        ("2.8.0", "2.7.7", 1),
        ("2.8.0", "2.8.0", 0),
        ("1.12.37", "1.12.37-SNAPSHOT", 0),
        ("1.12.37-SNAPSHOT", "1.13.1", -1),
        ("v2.8.0", "2.8.0", 0),
        ("2.8", "2.8.0", 0),
        ("2.8.1", "2.8", 1),
    ]
    for left, right, expected in cases:
        got = compare_tovarlite_version(left, right)
        assert got == expected, f"{left} vs {right}: expected {expected}, got {got}"


REQUIRED_PORTABLE_FILES = [
    ROOT / "portable" / "TovarLite.vbs",
    ROOT / "portable" / "README.txt",
    ROOT / "portable" / "App" / "Play.bat",
    ROOT / "portable" / "App" / "Update-TovarLite.ps1",
    ROOT / "portable" / "App" / "TovarLitePortableUI.ps1",
    ROOT / "portable" / "App" / "Launch-TovarLite.vbs",
    ROOT / "portable" / "App" / "EnsureLauncherCredentialsFlag.ps1",
    ROOT / "portable" / "App" / "Open-RuneLite-Configure.bat",
    ROOT / "portable" / "App" / "Re-import-settings.bat",
    ROOT / "scripts" / "Check-ClientFreshness.ps1",
    ROOT / "scripts" / "Resolve-ClientJar.ps1",
    ROOT / "scripts" / "Sync-Upstream.ps1",
    INSTALL_PS1,
]


def test_required_portable_files_exist() -> None:
    missing = [str(p) for p in REQUIRED_PORTABLE_FILES if not p.is_file()]
    assert not missing, f"missing files: {missing}"


def test_launcher_scripts_wire_auto_update() -> None:
    play = PLAY_BAT.read_text(encoding="utf-8")
    update = UPDATE_PS1.read_text(encoding="utf-8")
    ui = UI_PS1.read_text(encoding="utf-8")
    install = INSTALL_PS1.read_text(encoding="utf-8")

    assert "Update-TovarLite.ps1" in play
    assert "RuneLite.jar" in play
    assert "--noupdate" in play
    start_official = play.find('start "TovarLite" "!JAVA!" -jar "%~dp0RuneLite.jar"')
    start_fallback = play.find('start "TovarLite" "!JAVA!" -ea "!HUBARG!" -jar "!JARFILE!"')
    assert start_official != -1 and start_fallback != -1
    assert start_official < start_fallback
    assert "static.runelite.net" not in play  # client refresh is delegated to official launcher
    assert "runelite/launcher" in update
    assert "RuneLite.jar" in update
    assert "Invoke-TovarLiteUpdate" in ui
    assert "Checking for RuneLite updates" in ui
    assert "Update-TovarLite.ps1" in install
    assert "Play.bat" in install
    assert "Runtelite - Dev" in install


def test_install_patcher_file_list_matches_source() -> None:
    install = INSTALL_PS1.read_text(encoding="utf-8")
    expected = [
        "TovarLite.vbs",
        "README.txt",
        "App\\Play.bat",
        "App\\Update-TovarLite.ps1",
        "App\\TovarLitePortableUI.ps1",
        "App\\Launch-TovarLite.vbs",
        "App\\EnsureLauncherCredentialsFlag.ps1",
        "App\\Open-RuneLite-Configure.bat",
        "App\\Re-import-settings.bat",
    ]
    for rel in expected:
        assert rel in install, f"installer missing {rel}"
        assert (ROOT / "portable" / rel.replace("\\", "/")).is_file()


def test_bootstrap_is_newer_than_shipped_snapshot() -> None:
    bootstrap = fetch_json("https://static.runelite.net/bootstrap.json")
    version = str(bootstrap["version"])
    artifacts = bootstrap["artifacts"]
    assert artifacts, "bootstrap.json has no artifacts"
    assert any(str(a.get("name", "")).startswith("client-") for a in artifacts)
    assert any(str(a.get("name", "")).startswith("injected-client-") for a in artifacts)
    cmp = compare_tovarlite_version(version, "1.12.37-SNAPSHOT")
    assert cmp >= 0, f"unexpected bootstrap version {version}"
    print(f"bootstrap version {version} is current vs shipped 1.12.37-SNAPSHOT ({cmp=})")


def test_download_official_runelite_launcher_jar() -> None:
    release = fetch_json("https://api.github.com/repos/runelite/launcher/releases/latest")
    tag = release["tag_name"]
    assets = [a for a in release["assets"] if a["name"] == "RuneLite.jar"]
    assert assets, f"release {tag} has no RuneLite.jar"
    asset = assets[0]
    url = asset["browser_download_url"]
    size = int(asset["size"])
    assert size > 100_000
    assert compare_tovarlite_version(tag, "2.7.0") >= 0

    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    ctx = ssl.create_default_context()
    with tempfile.TemporaryDirectory() as tmp:
        jar_path = Path(tmp) / "RuneLite.jar"
        with urllib.request.urlopen(req, context=ctx, timeout=120) as resp:
            jar_path.write_bytes(resp.read())
        actual = jar_path.stat().st_size
        assert actual == size, f"size mismatch: {actual} != {size}"
        with zipfile.ZipFile(jar_path) as zf:
            names = zf.namelist()
        assert "net/runelite/launcher/Launcher.class" in names, "RuneLite.jar is not the official launcher"
        # Needs-update decision for the August TovarLite zip.
        assert compare_tovarlite_version(tag, "0.0.0") > 0
        print(f"downloaded official launcher {tag} ({actual} bytes)")


def main() -> None:
    test_required_portable_files_exist()
    test_version_compare_contract()
    test_launcher_scripts_wire_auto_update()
    test_install_patcher_file_list_matches_source()
    test_bootstrap_is_newer_than_shipped_snapshot()
    test_download_official_runelite_launcher_jar()
    print("all tovarlite auto-update tests passed")


if __name__ == "__main__":
    main()
