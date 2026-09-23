#!/usr/bin/env python3
"""Round-trip App/Resources/Localizable.xcstrings <-> a QA spreadsheet.

  Scripts/l10n/xcstrings_xlsx.py export  [out.xlsx]   # catalog -> xlsx
  Scripts/l10n/xcstrings_xlsx.py import  in.xlsx      # xlsx -> catalog (updates translations only)

Columns: key | English | Cantonese (zh-HK) | Taiwan (zh-Hant) | Mainland (zh-Hans) | notes
Only translations and notes change on import; keys and the English source
are never touched, and plural variations in the catalog are left alone.
Requires: pip install openpyxl
"""
import json, sys, pathlib
import openpyxl

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = ROOT / "App/Resources/Localizable.xcstrings"
LANGS = [("en", "English"), ("zh-HK", "Cantonese (zh-HK)"), ("zh-Hant", "Taiwan (zh-Hant)"), ("zh-Hans", "Mainland (zh-Hans)")]


def value(entry, lang):
    loc = entry.get("localizations", {}).get(lang)
    if not loc:
        return ""
    unit = loc.get("stringUnit")
    if unit:
        return unit["value"]
    plural = loc.get("variations", {}).get("plural", {})
    return (plural.get("other", {}).get("stringUnit", {}) or {}).get("value", "")


def export(out):
    cat = json.loads(CATALOG.read_text())
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "UI strings"
    ws.append(["key"] + [name for _, name in LANGS] + ["notes"])
    for key in sorted(cat["strings"]):
        entry = cat["strings"][key]
        ws.append([key] + [value(entry, code) for code, _ in LANGS] + [entry.get("comment", "")])
    for col, width in zip("ABCDEF", (46, 46, 46, 46, 46, 40)):
        ws.column_dimensions[col].width = width
    wb.save(out)
    print(f"wrote {out} ({len(cat['strings'])} strings)")


def import_(path):
    cat = json.loads(CATALOG.read_text())
    ws = openpyxl.load_workbook(path).active
    changed = 0
    for row in ws.iter_rows(min_row=2, values_only=True):
        key, *cells = row[:6]
        if key not in cat["strings"]:
            print(f"skip unknown key: {key!r}")
            continue
        entry = cat["strings"][key]
        locs = entry.setdefault("localizations", {})
        for (code, _), text in zip(LANGS[1:], cells[1:4]):
            if not text or code not in ("zh-HK", "zh-Hant", "zh-Hans"):
                continue
            unit = {"state": "translated", "value": str(text)}
            if locs.get(code, {}).get("stringUnit") != unit:
                locs[code] = {"stringUnit": unit}
                changed += 1
    CATALOG.write_text(json.dumps(cat, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"updated {changed} translations")


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "export":
        export(sys.argv[2] if len(sys.argv) > 2 else "CharaDUO-UI-strings.xlsx")
    elif len(sys.argv) == 3 and sys.argv[1] == "import":
        import_(sys.argv[2])
    else:
        sys.exit(__doc__)
