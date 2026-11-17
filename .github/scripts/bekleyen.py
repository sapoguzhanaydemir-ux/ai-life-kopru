"""İşlenmeyi bekleyen emirlerin müşterilerini bulur ve runner etiketleriyle listeler."""
import glob, json, os, re, unicodedata

def label(name):
    s = unicodedata.normalize('NFKD', name).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', '-', s).strip('-')

bekleyen = {}
for path in sorted(glob.glob('emirler/*.md')):
    if os.path.basename(path).startswith('_'):
        continue
    f = {}
    for line in open(path, encoding='utf-8'):
        m = re.match(r'^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*$', line.strip())
        if m and m.group(1) != 'Alan':
            f[m.group(1)] = m.group(2)
    musteri, durum, onay = f.get('Müşteri', ''), f.get('Durum', ''), f.get('Onay', '')
    if musteri and (durum == 'Verildi' or (durum == 'Onay bekliyor' and onay)):
        bekleyen[musteri] = label(musteri)

matrix = [{'musteri': m, 'label': l} for m, l in bekleyen.items()]
print('Bekleyen:', matrix or 'yok')
with open(os.environ.get('GITHUB_OUTPUT', '/dev/null'), 'a') as out:
    out.write('matrix=' + json.dumps(matrix) + '\n')
