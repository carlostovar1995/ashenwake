# Ashenwake VFX one-pager

Hand this to whoever authors meshes, particles, lights, or AnimationPlayer clips. Travel-body vs persist tagging stays in [AUTHORING.md](AUTHORING.md). This page is **what is cheap vs what drops FPS**.

Solar Collapse is the reference: `assets/vfx/elemental/effects/dawnwarden/solar_collapse_spell.tscn` → clip **`Solar Collpase Animation`**. Scale, explode rim, aura hide, fade, and Omni keys all live on that clip. Play/save the scene; combat loads it as-is.

---

## What actually costs FPS

| Cheap | Expensive |
| --- | --- |
| Scaling a low-poly mesh | Raising **particle amount**, sub-emitters, or unique materials per shot |
| Unshaded / `discard` shaders | Full-screen **transparent** meshes (overdraw) |
| One Omni, no shadows, modest range | Omni **parented under a scaled mesh**, shadows, volumetric fog |
| Shared ShaderMaterial | `new()` material or `queue_free()` every hit |
| AnimationPlayer on transform/shader params | Rebuilding meshes or lights every frame |

Vertex count of a 16×10 sphere is noise. **Pixels shaded** and **lights overlapping the cluster grid** are not.

---

## Meshes and animation

- Author **one** low-poly mesh (spheres ≤ 16×10, torii ≤ 8×24). Animate **scale / position / shader params**. Do not swap to a denser mesh for a “bigger” explosion.
- Huge look = **scale the same mesh** + a **rim/fresnel** shader (`explode` 0→1) so the interior `discard`s. A solid 50× transparent ball paints the whole frame twice.
- Hide extra shells once the blast is large (Solar Collapse hides **Solar Collapse Aura** ~4.52s).
- Default `SphereMesh` radius is **0.5 m**. Scale **1** = 0.5 m radius; scale **52** ≈ 26 m. Script still caps scale at **80** so a 500× key cannot freeze the GPU.
- Do not parent an OmniLight under a node you scale to 50. Combat detaches Collapse’s light (`top_level`) so **mesh scale does not multiply light range**.
- Keep clips in the `.tscn` (text). Combat plays the named AnimationPlayer clip; it does not bake a second copy.

---

## OmniLight: range vs energy vs scale

Forward+ is **clustered**. Each Omni is inserted into every cluster its **range sphere** overlaps. Cost is almost entirely **how much world the light covers** and **how many lights overlap**, not how bright it looks.

**Range (`omni_range`)** — the real budget knob. Bigger range = more clusters, more meshes in the light pass. A 40 m Omni in a 28 m arena lights everything, every frame. Collapse clamps range to **11 m**. For a “brighter sun,” raise **energy**, not range.

**Energy (`light_energy`)** — a brightness multiplier. Cheap by itself. It does not enlarge the light volume. Very high energy + glow/bloom can add **post-process** cost; Collapse clamps energy to **5.5**. Prefer energy 1–4 and a small range over energy 0.2 and range 40.

**Parent scale** — if the Omni is a child of `Meshes` and `Meshes.scale` is 52, Godot scales attenuation with the node. Range 8 becomes a stadium light. **Never scale the light with the explosion mesh.** Put the Omni on an unscaled parent, or keep `top_level` and snap it in script (Collapse does this).

**Shadows** — Omni shadows are a **cubemap (6 faces)**. One shadowed VFX Omni can cost more than the rest of the effect. Shadows **off**. `light_bake_mode` / GI **off**.

**Specular** — extra highlight term on every lit surface. Set **0** on VFX Omnis.

**Volumetric fog energy** — lights the fog volume. Set **0** unless fog is a deliberate look and you have profiled it.

**Count** — combat VFX Omnis go through `FxHeroLights` (**10** pooled slots, no shadows). Do not add a second Omni per spell for “more glow.” Dual infusion retints the one travel light.

**Rule of thumb:** one Omni, range ≤ **8–12**, energy ≤ **5**, no shadows, not parented to a scaled blast. Make the explosion with **mesh scale + emissive shader**, not with a bigger light.

---

## Particles (if you need them)

- Amount in the **tens**, not hundreds. Collapse’s sun uses **zero** particles for the blast.
- Lifetime **0.4–1.5 s**. Local Coords **off** for persist.
- No sub-emitters on a screen-filling burst. Fixed FPS **30** is fine.
- Sphere/bit draw passes beat high-poly smoke meshes.

---

## Checklist before you ship a clip

- [ ] Biggest visual is **scale + shader**, not a new mesh or extra Omni
- [ ] Transparent shells `discard` interiors; extra shells hide when huge
- [ ] Omni: unscaled parent or `top_level`; range small; energy for brightness; shadows off
- [ ] No unique material per instance; no `queue_free` on the hot path
- [ ] Playtest with overlapping ground AoEs + HUD; frame time should not dip vs the prior clip
