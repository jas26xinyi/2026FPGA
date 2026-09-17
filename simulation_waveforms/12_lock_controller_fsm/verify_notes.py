from pathlib import Path
import json, re

ROOT = Path(__file__).resolve().parent
views = json.loads((ROOT / 'views.json').read_text(encoding='utf-8'))
errors = []
for view in views:
    key = view['key']
    note = ROOT / 'notes' / (key + '.md')
    image = ROOT / 'images' / (key + '_native.png')
    cfg = ROOT / 'configs' / (key + '.wcfg')
    for path in (note, image, cfg):
        if not path.exists(): errors.append('missing ' + str(path))
    body = note.read_text(encoding='utf-8')
    required = ['原生 Vivado 截屏', '实际端口跳变、采样沿与效果', '0→1', '1→0', 'clk 上升沿', '实际功能']
    for phrase in required:
        if phrase not in body: errors.append(note.name + ': missing ' + phrase)
    if '_native.png)' not in body or '_annotated' in body: errors.append(note.name + ': wrong image reference')
    if '| 激励时刻/ns | 输入端口变化 | clk 上升沿/ns |' not in body: errors.append(note.name + ': missing event table')
    if len(re.findall(r'^\| \d+', body, re.M)) < 1: errors.append(note.name + ': no timed event rows')
if errors: raise SystemExit('\n'.join(errors))
print(f'PASS: {len(views)} notes reference native images and include edge/clock/effect tables')
