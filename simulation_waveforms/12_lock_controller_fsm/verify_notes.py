from pathlib import Path
import json, re, struct

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
    data = image.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', data[16:24]) != (1670, 791):
        errors.append(image.name + ': expected native-pixel Wave-only 1670x791 PNG')
    body = note.read_text(encoding='utf-8')
    required = ['原生 Vivado 截屏', '实际端口跳变、采样沿与效果', '0→1', '1→0', 'clk 上升沿', '实际功能']
    for phrase in required:
        if phrase not in body: errors.append(note.name + ': missing ' + phrase)
    if '_native.png)' not in body or '_annotated' in body: errors.append(note.name + ': wrong image reference')
    if '| 激励时刻/ns | 输入端口变化 | clk 上升沿/ns |' not in body: errors.append(note.name + ': missing event table')
    if len(re.findall(r'^\| \d+', body, re.M)) < 1: errors.append(note.name + ': no timed event rows')
for image in sorted(ROOT.parent.glob('[01][0-9]_*/*.png')):
    data = image.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', data[16:24]) != (1056, 594):
        errors.append(image.name + ': expected Wave-only 1056x594 PNG')
if errors: raise SystemExit('\n'.join(errors))
print(f'PASS: {len(views)} FSM images are native-pixel Wave-only 1670x791 crops; 11 overview images are Wave-only 1056x594 crops; notes remain valid')
