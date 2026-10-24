#!/usr/bin/env python3
"""Targeted airControl5.0.0 AirPlay artwork patch; preserves other local changes."""
import argparse
import json
import os
from pathlib import Path
import re
import tempfile
import time

OLD_FETCHER = r'''function fetchArtworkDataUrl({ url, timeout = 5000 } = {}, redirects = 0) {
  return new Promise((resolve) => {
    let parsed;
    try { parsed = new URL(String(url || "").trim()); }
    catch { return resolve({ok:false,status:0,error:"Invalid artwork URL"}); }
    if (!["http:","https:"].includes(parsed.protocol)) return resolve({ok:false,status:0,error:"Unsupported artwork protocol"});
    const transport = parsed.protocol === "https:" ? https : http;
    const req = transport.get(parsed, {timeout:Number(timeout)||5000, headers:{"User-Agent":"airControl/4.4.21","Accept":"image/*,*/*;q=0.8"}}, (res) => {
      if ([301,302,303,307,308].includes(res.statusCode) && res.headers.location && redirects < 4) {
        res.resume();
        const next = new URL(res.headers.location, parsed).toString();
        return fetchArtworkDataUrl({url:next,timeout}, redirects+1).then(resolve);
      }
      if (!(res.statusCode >= 200 && res.statusCode < 300)) { res.resume(); return resolve({ok:false,status:res.statusCode||0,error:`Artwork HTTP ${res.statusCode||0}`}); }
      const chunks=[]; let size=0; const max=5*1024*1024;
      res.on("data", c=>{ size+=c.length; if(size<=max) chunks.push(c); else req.destroy(new Error("Artwork too large")); });
      res.on("end", ()=>{
        if(size>max) return;
        const data=Buffer.concat(chunks); const mime=String(res.headers["content-type"]||"image/jpeg").split(";")[0].trim()||"image/jpeg";
        resolve({ok:true,status:res.statusCode,dataUrl:`data:${mime};base64,${data.toString("base64")}`,mime,size,sourceUrl:parsed.toString()});
      });
    });
    req.on("timeout", ()=>req.destroy(new Error("Artwork request timed out")));
    req.on("error", e=>resolve({ok:false,status:0,error:e.message}));
  });
}
'''
IMPORT = 'const { fetchArtworkDataUrl } = require("./artwork-fetch.cjs");\n'
START = "function fetchArtworkDataUrl("
END = 'ipcMain.handle("artwork:resolve"'
CALL = re.compile(r"window\.airCloud\.resolveArtworkUrl\(\{url:([^,}]+), timeout:5000\}\)")

def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name+".", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as out:
            out.write(text)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

def install(project):
    root = Path(project).expanduser().resolve()
    package = json.loads((root/"package.json").read_text(encoding="utf-8"))
    if package.get("version") != "5.0.0":
        raise ValueError("Патч рассчитан на airControl5.0.0; найдена версия "+str(package.get("version")))
    main_path, ui_path = root/"electron/main.cjs", root/"src/main.jsx"
    module_path = root/"electron/artwork-fetch.cjs"
    main, ui = main_path.read_text(encoding="utf-8"), ui_path.read_text(encoding="utf-8")
    module = (Path(__file__).resolve().parent.parent/"electron/artwork-fetch.cjs").read_text(encoding="utf-8")
    if IMPORT.strip() in main:
        if module_path.exists() and module_path.read_text(encoding="utf-8")==module and ui.count("deviceIp:target.ip})")==4:
            print("Патч AirPlayArtworkTLS-v1 уже установлен.")
            return
        raise ValueError("Обнаружена частичная или другая правка загрузчика; файлы не изменены.")
    a, b = main.find(START), main.find(END)
    if a<0 or b<a or main[a:b] != OLD_FETCHER:
        raise ValueError("Загрузчик отличается от проверенного5.0.0. Файлы не изменены; пришлите electron/main.cjs.")
    if module_path.exists() and module_path.read_text(encoding="utf-8") != module:
        raise ValueError("electron/artwork-fetch.cjs уже существует с другим содержимым; файлы не изменены.")
    patched_ui, count = CALL.subn(lambda m: "window.airCloud.resolveArtworkUrl({url:"+m.group(1)+", timeout:5000, deviceIp:target.ip})", ui)
    if count!=4:
        raise ValueError("Ожидалось4 вызова загрузки обложек, найдено"+str(count)+". Файлы не изменены.")
    patched_main = main[:a]+IMPORT+main[b:]
    targets = [(module_path,module), (ui_path,patched_ui), (main_path,patched_main)]
    backup = root/("backup-AirPlay-TLS-v1-"+time.strftime("%Y%m%d-%H%M%S")+"-"+str(time.time_ns()%1000000))
    backup.mkdir()
    originals={}
    for path,_ in targets:
        originals[path]=path.read_text(encoding="utf-8") if path.exists() else None
        if originals[path] is not None:
            dest=backup/path.relative_to(root)
            dest.parent.mkdir(parents=True,exist_ok=True)
            dest.write_text(originals[path],encoding="utf-8")
    (backup/"restore-info.json").write_text(json.dumps({
        "project":str(root),"patch":"AirPlayArtworkTLS-v1",
        "new_files":[str(p.relative_to(root)) for p,v in originals.items() if v is None]
    },ensure_ascii=False,indent=2),encoding="utf-8")
    try:
        for path,text in targets:
            atomic_write(path,text)
    except Exception:
        for path,text in originals.items():
            if text is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path,text)
        raise
    print("Готово: AirPlayArtworkTLS-v1 установлен в",root)
    print("Резервная копия:",backup)
    print("Версия приложения сохранена5.0.0. Запустите npm run dev.")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--project",required=True,help="Папка airControl-v5.0.0 с package.json")
    args=parser.parse_args()
    try:
        install(args.project)
    except Exception as exc:
        parser.exit(1,"Ошибка: "+str(exc)+"\n")
