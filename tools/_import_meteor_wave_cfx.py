"""Clone missile infusion scenes onto meteor/wave body meshes with baked import scale."""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(r"C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake")
PACK = Path(
    r"C:\Users\carlo\OneDrive\Desktop\GODOT - Magic Projectiles (Premium) [VFX only]"
    r"\VFX_Magic_Projectiles_(PREMIUM)\VFX\Objects"
)
INFUSIONS = (
    "fire",
    "ice",
    "lightning",
    "shadow",
    "nature",
    "divine",
    "protection",
    "wind",
    "illusion",
)
MISSILE_MESH = "res://assets/vfx/bases/missiles/Vfx/meshes/Custom Missile.obj"

# Meteor XY matches the old falling rock (80% of default 4.2 marker).
# Wave XY matches skillshot_width 2.6.
SPECS = {
    "meteor": {
        "src_obj": PACK / "fireball_mesh_st.obj",
        "src_mtl_name": "fireball_mesh.mtl",
        "dst_name": "fireball_mesh_st.obj",
        "xy": 1.7035,
        "target_xy": 2.0 * 4.2 * 0.80,
        "label": "Meteor",
    },
    "wave": {
        "src_obj": PACK / "sm_hadouken3.obj",
        "src_mtl_name": "sm_hadouken3.mtl",
        "dst_name": "sm_hadouken3.obj",
        "xy": 1.9051,
        "target_xy": 2.6,
        "label": "Wave",
    },
}

IMPORT = """[remap]

importer="wavefront_obj"
importer_version=1
type="Mesh"

[deps]

source_file="res://assets/vfx/bases/{base}/Vfx/meshes/{name}"

[params]

generate_tangents=true
generate_lods=true
generate_shadow_mesh=true
generate_lightmap_uv2=false
generate_lightmap_uv2_texel_size=0.2
scale_mesh=Vector3({scale}, {scale}, {scale})
offset_mesh=Vector3(0, 0, 0)
force_disable_mesh_compression=false
"""


def clone_text(src: Path, dst: Path, mesh_path: str, label: str) -> None:
    text = src.read_text(encoding="utf-8")
    text = text.replace(MISSILE_MESH, mesh_path)
    text = text.replace("Missiles", label)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(text, encoding="utf-8")


def main() -> None:
    for base, spec in SPECS.items():
        mesh_dir = ROOT / "assets" / "vfx" / "bases" / base / "Vfx" / "meshes"
        mesh_dir.mkdir(parents=True, exist_ok=True)
        dst_obj = mesh_dir / spec["dst_name"]
        shutil.copy2(spec["src_obj"], dst_obj)
        mtl = mesh_dir / spec["src_mtl_name"]
        mtl.write_text("# Blender MTL File: 'None'\n# www.blender.org\n", encoding="utf-8")
        scale = spec["target_xy"] / spec["xy"]
        (mesh_dir / f"{spec['dst_name']}.import").write_text(
            IMPORT.format(base=base, name=spec["dst_name"], scale=f"{scale:.6f}"),
            encoding="utf-8",
        )
        mesh_res = f"res://assets/vfx/bases/{base}/Vfx/meshes/{spec['dst_name']}"
        clone_text(
            ROOT / "assets" / "vfx" / "bases" / "missiles" / "body.tscn",
            ROOT / "assets" / "vfx" / "bases" / base / "body.tscn",
            mesh_res,
            spec["label"],
        )
        inf_root = ROOT / "assets" / "vfx" / "infusions"
        for inf in INFUSIONS:
            for slot in ("body", "persist"):
                src = inf_root / inf / f"missiles_{slot}.tscn"
                if not src.exists():
                    continue
                clone_text(
                    src,
                    inf_root / inf / f"{base}_{slot}.tscn",
                    mesh_res,
                    spec["label"],
                )
        print(f"{base}: scale_mesh={scale:.6f} mesh={dst_obj}")


if __name__ == "__main__":
    main()
