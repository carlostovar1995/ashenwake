import zipfile
from pathlib import Path

base = Path(__file__).parent
for zname in ["magic8.zip", "spells.zip", "kenney_rpg.zip"]:
    p = base / zname
    print(f"\n===== {zname} =====")
    try:
        with zipfile.ZipFile(p) as z:
            names = z.namelist()
            for i in names[:150]:
                print(i)
            print("... total", len(names))
    except Exception as e:
        print("ERR", e)

print("\n===== extracted dirs =====")
for p in sorted(base.iterdir()):
    print(p.name, "DIR" if p.is_dir() else p.stat().st_size)

print("\n===== magic8 folder =====")
m = base / "magic8"
if m.exists():
    files = [p for p in m.rglob("*") if p.is_file()]
    print("count", len(files))
    for p in files:
        print(p.relative_to(m), p.stat().st_size)

print("\n===== spells folder =====")
s = base / "spells"
if s.exists():
    files = [p for p in s.rglob("*") if p.is_file()]
    print("count", len(files))
    for p in files[:120]:
        print(p.relative_to(s))
