# ai-life-kopru

AI LIFE panelinden verilen iş emirlerinin müşteri makinelerindeki Claude Code'a taşındığı köprü reposu.

- `emirler/` · `sonuclar/` · `tanimlar/` · `notlar/` · `makine/<MÜŞTERİ>.md`
- Yürütücü kuralları: `CLAUDE.md`
- Yürütücü servisi: `yurutucu/bekci.ps1` (kurulum: `yurutucu/kur.ps1 -Makine <MÜŞTERİ>`)
- Sinyal: her makine durumunu `durum-<müşteri>` dalındaki `durum.json`'a yazar.
- Panel: https://sapoguzhanaydemir-ux.github.io/ai-life-panel/

## Yeni makine kurulumu (admin gerekmez)
1. Claude Code CLI kur ve giriş yap; VS Code ADT eklentisinde MCP sunucusunu aç.
2. `git clone https://github.com/sapoguzhanaydemir-ux/ai-life-kopru.git`
3. Repo klasöründe: `powershell -ExecutionPolicy Bypass -File .\yurutucu\kur.ps1 -Makine <MÜŞTERİ>`
