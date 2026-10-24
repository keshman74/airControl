#!/usr/bin/env python3
"""Install A31 relative AirPlay artwork path support into airControl 5.0.0."""
import argparse, json, os, tempfile, time
from pathlib import Path

OLD_MODULE = "\"use strict\";\nconst http = require(\"node:http\");\nconst https = require(\"node:https\");\nconst net = require(\"node:net\");\n\n// Limit the local-certificate exception to the selected LAN player's AirPlay\n// image. Re-evaluated at every redirect; public CDN TLS validation stays enabled.\nfunction localPlayerArtworkTlsOptions(parsed, deviceIp) {\n  if(parsed.protocol!==\"https:\" || parsed.hostname!==String(deviceIp||\"\").trim() ||\n     parsed.pathname!==\"/data/AirplayArtWorkData.jpeg\" || net.isIP(parsed.hostname)!==4) return {};\n  const parts=parsed.hostname.split(\".\").map(Number);\n  const privateIp=parts[0]===10 || (parts[0]===172 && parts[1]>=16 && parts[1]<=31) ||\n      (parts[0]===192 && parts[1]===168);\n  return privateIp ? {rejectUnauthorized:false} : {};\n}\n\nfunction fetchArtworkDataUrl({ url, timeout = 5000, deviceIp = \"\" } = {}, redirects = 0) {\n  return new Promise((resolve) => {\n    let parsed;\n    try { parsed = new URL(String(url || \"\").trim()); }\n    catch { return resolve({ok:false,status:0,error:\"Invalid artwork URL\"}); }\n    if (![\"http:\",\"https:\"].includes(parsed.protocol)) return resolve({ok:false,status:0,error:\"Unsupported artwork protocol\"});\n    const transport = parsed.protocol === \"https:\" ? https : http;\n    const req = transport.get(parsed, {timeout:Number(timeout)||5000, ...localPlayerArtworkTlsOptions(parsed, deviceIp), headers:{\"User-Agent\":\"airControl/4.4.21\",\"Accept\":\"image/*,*/*;q=0.8\"}}, (res) => {\n      if ([301,302,303,307,308].includes(res.statusCode) && res.headers.location && redirects < 4) {\n        res.resume();\n        const next = new URL(res.headers.location, parsed).toString();\n        return fetchArtworkDataUrl({url:next,timeout,deviceIp}, redirects+1).then(resolve);\n      }\n      if (!(res.statusCode >= 200 && res.statusCode < 300)) { res.resume(); return resolve({ok:false,status:res.statusCode||0,error:`Artwork HTTP ${res.statusCode||0}`}); }\n      const chunks=[]; let size=0; const max=5*1024*1024;\n      res.on(\"data\", c=>{ size+=c.length; if(size<=max) chunks.push(c); else req.destroy(new Error(\"Artwork too large\")); });\n      res.on(\"end\", ()=>{\n        if(size>max) return;\n        const data=Buffer.concat(chunks); const mime=String(res.headers[\"content-type\"]||\"image/jpeg\").split(\";\")[0].trim()||\"image/jpeg\";\n        resolve({ok:true,status:res.statusCode,dataUrl:`data:${mime};base64,${data.toString(\"base64\")}`,mime,size,sourceUrl:parsed.toString()});\n      });\n    });\n    req.on(\"timeout\", ()=>req.destroy(new Error(\"Artwork request timed out\")));\n    req.on(\"error\", e=>resolve({ok:false,status:0,error:e.message}));\n  });\n}\n\nmodule.exports={fetchArtworkDataUrl,localPlayerArtworkTlsOptions};\n"
OLD_CALL = "deviceIp:target.ip})"
NEW_CALL = "deviceIp:target.ip, deviceProtocol:target.protocol, devicePort:target.port})"
OLD_PARSER = "  const isRawPlayerAirPlayArtwork = value => {\n    try {\n      const parsed = new URL(String(value || \"\").trim());\n      return parsed.hostname === String(previous?.ip || \"\").trim() &&\n        parsed.pathname === \"/data/AirplayArtWorkData.jpeg\" &&\n        !parsed.protocol.startsWith(\"data:\");\n    } catch { return false; }\n  };\n  const usableArtwork = value => {\n    const art = String(value || \"\").trim();\n    return art && !isRawPlayerAirPlayArtwork(art) ? art : \"\";\n  };\n"
NEW_PARSER = "  const isPlayerAirPlayArtworkPath = pathname =>\n    pathname === \"/data/AirplayArtWorkData.jpeg\" ||\n    /^\\/data\\/airplay_[0-9a-f]{32}\\.jpg$/i.test(pathname);\n  const isRawPlayerAirPlayArtwork = value => {\n    const raw = String(value || \"\").trim();\n    try {\n      if (raw.startsWith(\"/\")) {\n        const relative = new URL(raw, \"http://airplay.invalid\");\n        return isPlayerAirPlayArtworkPath(relative.pathname);\n      }\n      const parsed = new URL(raw);\n      return parsed.hostname === String(previous?.ip || \"\").trim() &&\n        isPlayerAirPlayArtworkPath(parsed.pathname);\n    } catch { return false; }\n  };\n  const usableArtwork = value => {\n    const art = String(value || \"\").trim();\n    return art && !isRawPlayerAirPlayArtwork(art) ? art : \"\";\n  };\n"

def atomic_write(path, text):
    fd, tmp = tempfile.mkstemp(prefix=path.name+".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as f: f.write(text)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)

def install(project):
    root=Path(project).expanduser().resolve()
    pkg=json.loads((root/"package.json").read_text(encoding="utf-8"))
    if pkg.get("version")!="5.0.0":
        raise ValueError("Патч рассчитан на airControl 5.0.0.")
    main_path=root/"src/main.jsx"
    drivers_path=root/"src/services/deviceDrivers.js"
    module_path=root/"electron/artwork-fetch.cjs"
    main=main_path.read_text(encoding="utf-8")
    drivers=drivers_path.read_text(encoding="utf-8")
    module=module_path.read_text(encoding="utf-8")
    bundled=(Path(__file__).resolve().parent.parent/"electron/artwork-fetch.cjs").read_text(encoding="utf-8")

    calls_done=main.count(NEW_CALL)==4 and OLD_CALL not in main
    parser_done=NEW_PARSER in drivers and OLD_PARSER not in drivers
    if calls_done and parser_done and module.rstrip("\n")==bundled.rstrip("\n"):
        print("AirPlayArtworkPath-v1 уже установлен.")
        return
    if module.rstrip("\n")!=OLD_MODULE.rstrip("\n"):
        raise ValueError("Сначала установите AirPlayArtworkTLS-v1: модуль загрузчика отличается. Файлы не изменены.")
    if OLD_CALL not in main or main.count(OLD_CALL)!=4:
        raise ValueError("Ожидались четыре проверенных вызова resolver с deviceIp. Файлы не изменены.")
    if OLD_PARSER not in drivers or drivers.count(OLD_PARSER)!=1:
        raise ValueError("Сначала установите AirPlayArtworkStability-v1: фильтр парсера отличается. Файлы не изменены.")

    new_main=main.replace(OLD_CALL,NEW_CALL)
    new_drivers=drivers.replace(OLD_PARSER,NEW_PARSER,1)
    targets=[(main_path,new_main),(drivers_path,new_drivers),(module_path,bundled)]
    backup=root/("backup-AirPlayArtworkPath-v1-"+time.strftime("%Y%m%d-%H%M%S")+"-"+str(time.time_ns()%1000000))
    backup.mkdir()
    originals={}
    for path,_ in targets:
        originals[path]=path.read_text(encoding="utf-8")
        dest=backup/path.relative_to(root)
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_text(originals[path],encoding="utf-8")
    (backup/"restore-info.json").write_text(json.dumps({"project":str(root),"patch":"AirPlayArtworkPath-v1"},ensure_ascii=False,indent=2),encoding="utf-8")
    try:
        for path,text in targets: atomic_write(path,text)
    except Exception:
        for path,text in originals.items(): atomic_write(path,text)
        raise
    print("Готово: AirPlayArtworkPath-v1 установлен.")
    print("Резервная копия:",backup)
    print("Поддержан A31 путь /data/airplay_<32-hex>.jpg с адресом из выбранной зоны.")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--project",required=True)
    a=p.parse_args()
    try: install(a.project)
    except Exception as e: p.exit(1,"Ошибка: "+str(e)+"\n")
