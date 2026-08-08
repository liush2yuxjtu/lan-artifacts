#!/bin/bash
# 发布"LAN Artifacts 首页"到本地 LAN server(4173):
#   首页内容 = 自包含 HTML, JS 动态 fetch GitHub Pages 的 artifacts.json 渲染列表
#   → 每次打开/刷新都是最新, 无需重新发布; 重新运行本脚本则发布新版本(SSE 实时刷新打开中的 viewer)
# 用法: tools/publish-homepage.sh
set -euo pipefail

TOKEN="$(grep -o 'LAN_ARTIFACT_WRITE_TOKEN=.*' "$HOME/.claude-artifacts/.env" | cut -d= -f2)"
TITLE="🏠 LAN Artifacts 首页 · 公开存档"
PAGES="https://liush2yuxjtu.github.io/lan-artifacts"

HTML=$(cat << 'EOF'
<!DOCTYPE html>
<html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LAN Artifacts 首页 · 公开存档</title>
<style>
 body{margin:0;font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif;background:#101318;color:#e8eaed;padding:28px 16px;max-width:820px;margin:0 auto}
 h1{font-size:22px;margin:0 0 4px} .sub{color:#7a8291;font-size:13px;margin:0 0 20px;line-height:1.7}
 a{color:#8ab4f8;text-decoration:none}
 #st{color:#4a5261;font-size:12px;margin-left:10px}
 ul{list-style:none;padding:0;display:flex;flex-direction:column;gap:10px}
 .art{background:#171a21;border:1px solid #262b36;border-radius:10px;padding:12px 16px;display:flex;gap:12px;align-items:center;transition:border-color .15s}
 .art:hover{border-color:#3a4660}
 .em{font-size:22px} .info{flex:1;min-width:0}
 .title{font-size:15px} .meta{color:#7a8291;font-size:12px;margin-top:2px}
 .go{color:#4a5261;font-size:16px}
 .bad{background:#262b36;color:#7a8291;border-radius:6px;padding:6px 12px;font-size:13px;display:inline-block}
</style></head><body>
<h1>LAN Artifacts 首页 · 公开存档</h1>
<p class="sub">herdr-wecom-bot-bridge 开发过程的公开 Artifacts。<br>
公开站(任何人可访问): <a href="__PAGES__" target="_blank">__PAGES__</a><span id="st"></span></p>
<div id="list"><span class="bad">加载中…</span></div>
<script>
const PAGES='__PAGES__';
async function load(){
  const st=document.getElementById('st');st.textContent='…刷新中';
  try{
    const r=await fetch(PAGES+'/artifacts.json');
    const arts=await r.json();
    const ul=document.createElement('ul');
    for(const a of arts){
      const li=document.createElement('li');li.className='art';
      const em=document.createElement('span');em.className='em';em.textContent=a.emoji||'📄';
      const info=document.createElement('div');info.className='info';
      const t=document.createElement('a');t.className='title';t.href=PAGES+'/a/'+a.id+'.html';t.target='_blank';t.textContent=a.title;
      const m=document.createElement('div');m.className='meta';
      const d=new Date(a.updated_at);m.textContent=(d.toString()==='Invalid Date'?'':d.toLocaleString('zh-CN',{month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'}))+' · '+a.version_count+' 版';
      const g=document.createElement('span');g.className='go';g.textContent='›';
      info.append(t,m);li.append(em,info,g);ul.append(li);
    }
    const list=document.getElementById('list');list.textContent='';list.append(ul);
    st.textContent='('+arts.length+' 个 · 更新于 '+new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})+')';
  }catch(e){document.getElementById('list').innerHTML='<span class="bad">加载失败: '+e.message+'</span>';st.textContent='';}
}
load();setInterval(load,60000); // 每分钟自刷新 — 打开即最新
</script></body></html>
EOF
)

HTML="${HTML//__PAGES__/$PAGES}"

# 幂等: 已有同名 artifact 则 appendVersion, 否则 create
EXISTING=$(curl -s http://127.0.0.1:4173/api/artifacts | python3 -c "
import json,sys
for a in json.load(sys.stdin):
    if a['title'] == '$TITLE':
        print(a['id']); break
")
BODY=$(python3 - "$HTML" << 'PYEOF'
import json, sys
html = sys.argv[1]
print(json.dumps({"title": "🏠 LAN Artifacts 首页 · 公开存档", "emoji": "🏠", "html": html}))
PYEOF
)
if [ -n "$EXISTING" ]; then
  curl -s -X POST -H "x-artifact-write-token: $TOKEN" -H "content-type: application/json" -d "$BODY" \
    "http://127.0.0.1:4173/api/artifacts/$EXISTING/versions" | python3 -c "import json,sys; d=json.load(sys.stdin); print('首页更新 v'+str(d['version']), d['url'])"
else
  curl -s -X POST -H "x-artifact-write-token: $TOKEN" -H "content-type: application/json" -d "$BODY" \
    "http://127.0.0.1:4173/api/artifacts" | python3 -c "import json,sys; d=json.load(sys.stdin); print('首页创建 v'+str(d['version']), d['url'])"
fi
