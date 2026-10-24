#!/usr/bin/env python3
"""Install the v2 AirPlay cover stability guard into airControl 5.0.0."""
import argparse, json, os, tempfile, time
from pathlib import Path

OLD = "  const richArtwork = sameTrackForArtwork ? String(rich?.albumArtURI || rich?.[\"albumArtURI \"] || \"\").trim() : \"\";\n  const upnpArtwork = String(upnp?.art || \"\").trim();\n"
NEW = "  // Local AirPlay artwork is fetched by Electron and converted to a data URL.\n  // Never send the player's raw /data image URL to Chromium: these players use\n  // self-signed HTTPS certificates, so an occasional resolver miss makes the\n  // browser drop the image. During a transient miss, keep the last good data URL.\n  const isRawPlayerAirPlayArtwork = value => {\n    try {\n      const parsed = new URL(String(value || \"\").trim());\n      return parsed.hostname === String(previous?.ip || \"\").trim() &&\n        parsed.pathname === \"/data/AirplayArtWorkData.jpeg\" &&\n        !parsed.protocol.startsWith(\"data:\");\n    } catch { return false; }\n  };\n  const usableArtwork = value => {\n    const art = String(value || \"\").trim();\n    return art && !isRawPlayerAirPlayArtwork(art) ? art : \"\";\n  };\n  const richArtwork = sameTrackForArtwork ? usableArtwork(rich?.albumArtURI || rich?.[\"albumArtURI \"]) : \"\";\n  const upnpArtwork = usableArtwork(upnp?.art);\n  const previousArtwork = usableArtwork(previous?.track?.art);\n"
OLD_FALLBACK = '(titleChanged ? "" : (previous.track?.art || ""))'
NEW_FALLBACK = '(titleChanged ? "" : previousArtwork)'

def atomic_write(path, text):
    fd, tmp = tempfile.mkstemp(prefix=path.name+".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as f: f.write(text)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)

def install(root):
    root = Path(root).expanduser().resolve()
    pkg = json.loads((root/"package.json").read_text(encoding="utf-8"))
    if pkg.get("version") != "5.0.0":
        raise ValueError("Patch рассчитан на airControl 5.0.0.")
    path = root/"src/services/deviceDrivers.js"
    source = path.read_text(encoding="utf-8")
    if NEW in source and source.count(NEW) == 1 and source.count(NEW_FALLBACK) == 2:
        print("AirPlayArtworkStability-v1 уже установлен.")
        return
    if OLD not in source or source.count(OLD) != 1 or source.count(OLD_FALLBACK) != 2:
        raise ValueError("Код парсера отличается от ожидаемой версии; файлы не изменены.")
    updated = source.replace(OLD, NEW, 1).replace(OLD_FALLBACK, NEW_FALLBACK)
    backup = root/("backup-AirPlay-artwork-stability-v1-"+time.strftime("%Y%m%d-%H%M%S")+"-"+str(time.time_ns()%1000000))
    backup.mkdir()
    (backup/"src/services").mkdir(parents=True)
    (backup/"src/services/deviceDrivers.js").write_text(source, encoding="utf-8")
    (backup/"restore-info.json").write_text(json.dumps({"project":str(root),"patch":"AirPlayArtworkStability-v1"},ensure_ascii=False,indent=2),encoding="utf-8")
    try: atomic_write(path, updated)
    except Exception:
        atomic_write(path, source)
        raise
    print("Готово: AirPlayArtworkStability-v1 установлен.")
    print("Резервная копия:", backup)

if __name__ == "__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--project",required=True)
    a=p.parse_args()
    try: install(a.project)
    except Exception as e: p.exit(1,"Ошибка: "+str(e)+"\n")
