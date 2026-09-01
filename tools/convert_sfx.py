"""Convert public-domain / CC-BY sources into uniquely named game SFX."""
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INC = ROOT / "_incoming" / "audio"
OUT = ROOT / "assets" / "audio" / "sfx"
FFMPEG = "ffmpeg"

MAGIC = INC / "magic8"
KENNEY = INC / "kenney_rpg" / "OGG"
ICE = INC / "ice_elec" / "qubodupIceAndElectricitySpells"
JAG = INC


def run(args: list[str]) -> None:
    subprocess.check_call(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def convert(src: Path, dest: Path, af: str | None = None, extra: list[str] | None = None) -> None:
    if not src.exists():
        raise FileNotFoundError(src)
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd = [FFMPEG, "-y", "-i", str(src)]
    if extra:
        cmd.extend(extra)
    if af:
        cmd.extend(["-af", af])
    cmd.extend(["-c:a", "libvorbis", "-q:a", "5", str(dest)])
    run(cmd)
    print("wrote", dest.name, dest.stat().st_size)


def loop_slice(src: Path, dest: Path, start: float, dur: float, af_extra: str = "") -> None:
    fade = min(0.12, dur * 0.22)
    parts = [
        f"atrim=start={start}:duration={dur}",
        "asetpts=PTS-STARTPTS",
        f"afade=t=in:st=0:d={fade}",
        f"afade=t=out:st={max(dur - fade, 0.0)}:d={fade}",
    ]
    if af_extra:
        parts.append(af_extra)
    convert(src, dest, ",".join(parts))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    convert(MAGIC / "45_Charge_05.wav", OUT / "firebolt_cast.ogg", "atrim=0:1.35,afade=t=out:st=1.15:d=0.2")
    convert(KENNEY / "cloth1.ogg", OUT / "firebolt_cast_ember.ogg")
    loop_slice(MAGIC / "04_Fire_explosion_04_medium.wav", OUT / "firebolt_travel.ogg", 0.28, 1.05, "volume=0.55,highpass=f=250")
    convert(MAGIC / "04_Fire_explosion_04_medium.wav", OUT / "firebolt_explode.ogg")
    convert(KENNEY / "metalPot1.ogg", OUT / "firebolt_scatter.ogg", "volume=1.4")

    convert(MAGIC / "13_Ice_explosion_01.wav", OUT / "freeze_blast.ogg")
    convert(KENNEY / "cloth2.ogg", OUT / "freeze_blast_air.ogg", "asetrate=44100*1.15,aresample=44100")
    convert(ICE / "qubodupIceDamage01.flac", OUT / "freeze_hit.ogg")
    convert(ICE / "qubodupIceDamage03.flac", OUT / "freeze_lock.ogg")

    convert(INC / "electricspell.ogg", OUT / "thunder_cast.ogg", "atrim=0:1.55,afade=t=out:st=1.35:d=0.2")
    convert(ICE / "qubodupElectricityDamage01.flac", OUT / "thunder_hop.ogg")

    loop_slice(MAGIC / "30_Earth_02.wav", OUT / "meteor_channel.ogg", 0.2, 1.4, "lowpass=f=420,volume=0.85")
    convert(MAGIC / "25_Wind_01.wav", OUT / "meteor_fall.ogg", "asetrate=44100*0.82,aresample=44100,afade=t=in:d=0.08")
    convert(MAGIC / "30_Earth_02.wav", OUT / "meteor_impact.ogg", "volume=1.25")
    convert(JAG / "magical_4.ogg", OUT / "meteor_bloom.ogg", "asetrate=44100*0.78,aresample=44100")

    convert(MAGIC / "22_Water_02.wav", OUT / "chilled_place.ogg")
    loop_slice(ICE / "qubodupIceDamage03b.flac", OUT / "chilled_loop.ogg", 0.05, 0.85, "volume=0.7,lowpass=f=1800")

    convert(JAG / "magical_7.ogg", OUT / "overcharge_activate.ogg")
    convert(JAG / "magical_1.ogg", OUT / "overcharge_fire.ogg")
    convert(JAG / "magical_2.ogg", OUT / "overcharge_ice.ogg")
    convert(MAGIC / "18_Thunder_02.wav", OUT / "overcharge_storm.ogg", "atrim=0:1.2,volume=0.7")
    loop_slice(JAG / "magical_3.ogg", OUT / "overcharge_loop.ogg", 0.0, 0.7, "volume=0.8")

    convert(JAG / "magical_5.ogg", OUT / "auto_fire.ogg")
    convert(KENNEY / "knifeSlice.ogg", OUT / "auto_hit.ogg")
    convert(KENNEY / "chop.ogg", OUT / "melee_hit.ogg")

    convert(JAG / "magical_4.ogg", OUT / "combust.ogg", "asetrate=44100*0.92,aresample=44100")
    convert(KENNEY / "doorClose_1.ogg", OUT / "cataclysm.ogg", "volume=1.6")
    convert(ICE / "qubodupIceDamage02.flac", OUT / "shatter.ogg")

    convert(JAG / "magical_6.ogg", OUT / "boss_warn.ogg")
    convert(KENNEY / "knifeSlice2.ogg", OUT / "colossus_cleave.ogg", "volume=1.35")
    convert(KENNEY / "metalPot3.ogg", OUT / "colossus_slam.ogg", "volume=1.7")
    convert(KENNEY / "cloth3.ogg", OUT / "colossus_breath.ogg", "asetrate=44100*0.72,aresample=44100,volume=1.5")

    convert(MAGIC / "46_Poison_01.wav", OUT / "dawn_cleave.ogg")
    convert(KENNEY / "doorClose_4.ogg", OUT / "dawn_sunspot.ogg", "volume=1.8")
    convert(INC / "electricspell2.ogg", OUT / "dawn_ray_warn.ogg", "atrim=0:0.85,afade=t=out:st=0.7:d=0.15")
    loop_slice(ICE / "qubodupElectricityDamage02.flac", OUT / "dawn_ray_loop.ogg", 0.02, 0.7, "volume=0.75")
    loop_slice(MAGIC / "45_Charge_05.wav", OUT / "dawn_collapse_warn.ogg", 0.4, 1.6, "asetrate=44100*0.7,aresample=44100,lowpass=f=500,volume=0.9")
    convert(MAGIC / "18_Thunder_02.wav", OUT / "dawn_collapse_impact.ogg", "volume=1.35,lowpass=f=2500")

    print("done", len(list(OUT.glob("*.ogg"))), "files")


if __name__ == "__main__":
    main()
