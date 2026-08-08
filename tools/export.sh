#!/bin/bash
# 导出 ~/.claude-artifacts 为纯静态站(适合 GitHub Pages):
#   index.html  全部 artifacts 列表(最新版本)
#   v/<id>/     每个版本的原始 html(自包含, 直接可看)
#   a/<id>.html 包装页(标题 + iframe + 历史版本切换)
# 用法: tools/export.sh   (在 repo 根运行)
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${LAN_ARTIFACT_DIR:-$HOME/.claude-artifacts}"
SITE="site"

rm -rf "$SITE"
mkdir -p "$SITE/v" "$SITE/a"

# 1. 版本 html 原样复制
cp -R "$SRC/html/." "$SITE/v/"

# 2. 生成列表页
python3 - "$SITE" "$SRC" << 'PYEOF'
import html, json, sys
from pathlib import Path

site, src = Path(sys.argv[1]), Path(sys.argv[2])
index = json.loads((src / "index.json").read_text())
arts = sorted(index.get("artifacts", []), key=lambda a: a.get("updated_at", ""), reverse=True)

def art_link(a):
    aid = a["id"]
    n = a.get("version") or 1
    latest = f"v{n}.html"
    for i in range(n, 0, -1):
        if (site / "v" / aid / f"v{i}.html").exists():
            latest = f"v{i}.html"
            break
    title = html.escape(a.get("title") or aid)
    date = (a.get("updated_at") or "")[:16].replace("T", " ")
    return f"""<li class="art">
  <a class="title" href="a/{aid}.html">{title}</a>
  <span class="date">{html.escape(date)}</span>
  <span class="id">{aid[8:16]}</span>
</li>"""

rows = "\n".join(art_link(a) for a in arts)
page = f"""<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LAN Artifacts — 公开存档</title>
<style>
 body{{margin:0;font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif;background:#101318;color:#e8eaed;padding:32px 16px;max-width:760px;margin:0 auto}}
 h1{{font-size:20px}} p{{color:#7a8291;font-size:13px;line-height:1.6}}
 ul{{list-style:none;padding:0;display:flex;flex-direction:column;gap:10px}}
 .art{{background:#171a21;border:1px solid #262b36;border-radius:10px;padding:12px 16px;display:flex;gap:12px;align-items:baseline}}
 .title{{color:#8ab4f8;text-decoration:none;font-size:15px;flex:1}}
 .date{{color:#7a8291;font-size:12px}}
 .id{{color:#4a5261;font-size:11px;font-family:monospace}}
</style></head><body>
<h1>LAN Artifacts 公开存档</h1>
<p>这些是 herdr-wecom-bot-bridge 开发过程中的自托管 Artifacts 快照。点标题查看完整内容。</p>
<ul>{rows}</ul>
</body></html>"""
(site / "index.html").write_text(page)
print(f"index.html: {len(arts)} artifacts")
PYEOF

# 3. 每个 artifact 生成包装页(iframe + 版本切换)
python3 - "$SITE" "$SRC" << 'PYEOF'
import html, json, sys
from pathlib import Path

site, src = Path(sys.argv[1]), Path(sys.argv[2])
index = json.loads((src / "index.json").read_text())
for a in index.get("artifacts", []):
    aid = a["id"]
    vdir = site / "v" / aid
    if not vdir.exists():
        continue
    versions = sorted(p.stem[1:] for p in vdir.glob("v*.html"))
    if not versions:
        continue
    latest = versions[-1]
    title = html.escape(a.get("title") or aid)
    opts = "\n".join(f'<option value="{v}">v{v}</option>' for v in reversed(versions))
    page = f"""<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — LAN Artifacts</title>
<style>
 body{{margin:0;font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif;background:#101318;color:#e8eaed;height:100vh;display:flex;flex-direction:column}}
 header{{padding:8px 16px;background:#171a21;border-bottom:1px solid #262b36;display:flex;gap:12px;align-items:center;font-size:13px}}
 a{{color:#8ab4f8;text-decoration:none}} select{{background:#0f1115;color:#e8eaed;border:1px solid #2c3340;border-radius:6px;padding:4px 8px}}
 iframe{{flex:1;border:0;width:100%}}
</style></head><body>
<header><a href="../">←</a><b>{title}</b>
<select id="ver">{opts}</select>
<a id="raw" target="_blank" href="../v/{aid}/v{latest}.html">原始</a></header>
<iframe id="frame" src="../v/{aid}/v{latest}.html"></iframe>
<script>
 const sel=document.getElementById('ver'),f=document.getElementById('frame'),raw=document.getElementById('raw');
 sel.onchange=()=>{{const v=sel.value;f.src=`../v/{aid}/v${{v}}.html`;raw.href=`../v/{aid}/v${{v}}.html`}};
</script>
</body></html>"""
    (site / "a" / f"{aid}.html").write_text(page)
print("wrapper pages done")
PYEOF

echo "site ready: $SITE ($(du -sh "$SITE" | cut -f1))"
