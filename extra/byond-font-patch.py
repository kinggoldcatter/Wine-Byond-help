#!/usr/bin/env python3
"""
byond-font-patch.py - merge missing Unicode glyphs into the four core fonts that
WebView2/BYOND actually use inside a Wine prefix (arial, times, tahoma, micross),
so Chromium's font fallback never has to run for them.

Why: WebView2 under Wine ignores Linux fontconfig and (in practice) ignores fonts
merely installed into C:\\windows\\Fonts. Merging the outlines directly into the
fonts Chromium already resolves is what works (verified approach).

Important constraints learned the hard way (keep them):
  * Do NOT use Noto Sans Math outlines - they make Wine/DirectWrite spin at 100%
    CPU and BYOND never opens its window. Use Symbola (preferred) or another
    TrueType math font as the math source.
  * Preserve hinting tables (gasp, cvt, fpgm, prep) and never touch existing
    glyphs, so normal text keeps its appearance and ASCII advance widths.
  * Prefix font files are often SYMLINKS into a Proton/Wine runtime. Replacing
    them with os.replace() replaces the symlink, not the shared runtime file, and
    originals are copied to backup-originals/ as regular files.

Usage:
  byond-font-patch.py --prefix ~/Games/byond
  byond-font-patch.py --prefix ~/Games/byond --verify
  byond-font-patch.py --prefix ~/Games/byond --revert
  byond-font-patch.py --prefix ~/Games/byond --chars "𓊈😀ᛣ𝓰"
  byond-font-patch.py --prefix ~/Games/byond --no-emoji
"""
from __future__ import annotations

import argparse
import os
import shutil
import struct
import sys
import tempfile

try:
    from fontTools.ttLib import TTFont
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.pens.recordingPen import DecomposingRecordingPen
    from fontTools.misc.transform import Transform
    from fontTools.ttLib.tables._c_m_a_p import CmapSubtable
except ImportError:
    sys.exit("fontTools is required (python-fonttools / pip install fonttools)")

BASE_FONTS = ["arial", "times", "tahoma", "micross"]

# Codepoint ranges copied from each source font (only cps actually present).
RANGES = {
    "egypt": [(0x13000, 0x1342F), (0x13460, 0x143FF)],
    "runic": [(0x16A0, 0x16FF)],
    "emoji": [(0x2600, 0x27BF), (0x2B00, 0x2BFF), (0x1F000, 0x1FAFF), (0x1F1E6, 0x1F1FF)],
    "math": [(0x1D400, 0x1D7FF)],
}

SEARCH = {
    "egypt": [
        os.environ.get("BYOND_EGYPT_FONT", ""),
        "/usr/share/fonts/noto/NotoSansEgyptianHieroglyphs-Regular.ttf",
        "/usr/share/fonts/TTF/NotoSansEgyptianHieroglyphs-Regular.ttf",
    ],
    "runic": [
        os.environ.get("BYOND_RUNIC_FONT", ""),
        "/usr/share/fonts/noto/NotoSansRunic-Regular.ttf",
        "/usr/share/fonts/TTF/NotoSansRunic-Regular.ttf",
    ],
    "emoji": [
        os.environ.get("BYOND_EMOJI_FONT", ""),
        "/usr/share/fonts/noto/NotoEmoji-Regular.ttf",
        "/usr/share/fonts/noto/NotoEmoji-VariableFont_wght.ttf",
    ],
    # Symbola first (proven), then other TrueType math fonts. Noto Sans Math is
    # intentionally NOT in the default list (causes the hang).
    "math": [
        os.environ.get("BYOND_MATH_FONT", ""),
        "/usr/share/fonts/TTF/Symbola.ttf",
        "/usr/share/fonts/truetype/symbola/Symbola.ttf",
        "/usr/share/fonts/TTF/DejaVuMathTeXGyre.ttf",
        "/usr/share/fonts/dejavu/DejaVuMathTeXGyre.ttf",
    ],
}

HINT_TABLES = ["gasp", "cvt ", "fpgm", "prep"]


def first_existing(paths):
    for p in paths:
        if p and os.path.isfile(p):
            return p
    return None


def ensure_cmap12(base):
    """Return a Unicode format-12 subtable, creating a complete one if the font
    only ships BMP (format 4) coverage. Without this, codepoints above U+FFFF
    (hieroglyphs, emoji, math alphanumerics) are merged but never mapped."""
    for t in base["cmap"].tables:
        if t.format in (12, 13) and t.isUnicode():
            return t
    full = {}
    for t in base["cmap"].tables:
        if t.isUnicode():
            full.update(t.cmap)
    sub = CmapSubtable.newSubtable(12)
    sub.platformID = 3
    sub.platEncID = 10
    sub.language = 0
    sub.format = 12
    sub.cmap = dict(full)
    base["cmap"].tables.append(sub)
    return sub


def cp_in_ranges(cp, ranges):
    return any(lo <= cp <= hi for lo, hi in ranges)


def collect_cps(cmap, ranges):
    return sorted(cp for cp in cmap if cp_in_ranges(cp, ranges))


def load_source(path, label):
    font = TTFont(path, lazy=False, fontNumber=0)
    if "fvar" in font:
        try:
            from fontTools.varLib.instancer import instantiateVariableFont
            instantiateVariableFont(font, {"wght": 400}, inplace=True)
            print(f"  {label}: instantiated variable font at wght=400")
        except Exception as exc:  # keep default instance on failure
            print(f"  {label}: variable instancing skipped ({exc})")
    return font


def glyph_add(font, name, source_glyph_set, scale, source_hmtx):
    pen = TTGlyphPen(None)
    target = TransformPen(pen, Transform(scale, 0, 0, scale, 0, 0)) if scale != 1.0 else pen
    # Decompose composite glyphs first: TTGlyphPen(None) cannot resolve component
    # glyphs, so drawing a composite directly raises and the glyph would be
    # silently dropped (this lost ~68 math and ~10 emoji glyphs before).
    drp = DecomposingRecordingPen(source_glyph_set)
    source_glyph_set[name].draw(drp)
    drp.replay(target)
    glyph = pen.glyph()
    advance, lsb = source_hmtx[name]
    return glyph, (round(advance * scale), round(lsb * scale))


def finalize_glyph_tables(base, order, hmtx, added):
    """Sync glyph order / metrics bookkeeping after appending glyphs.

    hhea.numberOfHMetrics MUST equal len(hmtx.metrics) or trailing glyphs reuse
    the previous advance width; post (format 2) must carry the new order too."""
    base.setGlyphOrder(order)
    base["maxp"].numGlyphs = len(order)
    if "hhea" in base:
        base["hhea"].numberOfHMetrics = len(hmtx.metrics)
    if "post" in base and getattr(base["post"], "formatType", 3.0) == 2.0:
        base["post"].glyphOrder = order
    if "OS/2" in base and added:
        os2 = base["OS/2"]
        os2.usFirstCharIndex = min([os2.usFirstCharIndex] + [min(added)])
        os2.usLastCharIndex = max([os2.usLastCharIndex] + [min(0xFFFF, max(added))])
    glyf = base["glyf"]
    for gname in order:
        g = glyf.glyphs.get(gname)
        if g is not None and hasattr(g, "recalcBounds"):
            g.recalcBounds(glyf)


def merged_font(base_path, sources, extra_chars):
    """Return a TTFont with extra glyphs merged in, plus a report dict."""
    base = TTFont(base_path, lazy=False, fontNumber=0)
    base_upem = base["head"].unitsPerEm
    glyf = base["glyf"]
    hmtx = base["hmtx"]

    order = list(base.getGlyphOrder())
    cmaps = [t for t in base["cmap"].tables if t.isUnicode()]
    cmap12 = ensure_cmap12(base)
    added = {}
    per_source = {}

    for label, path in sources.items():
        src = load_source(path, label)
        s_upem = src["head"].unitsPerEm
        scale = base_upem / s_upem
        s_cmap = src.getBestCmap()
        s_gs = src.getGlyphSet()
        s_hmtx = src["hmtx"]

        if label == "extra":
            wanted = [ord(c) for c in extra_chars]
        else:
            wanted = collect_cps(s_cmap, RANGES[label])

        count = 0
        for cp in wanted:
            if cp not in s_cmap:
                continue
            if any(t.cmap.get(cp) for t in cmaps):
                continue
            new_name = f"byond{cp:06X}"
            if new_name in glyf.glyphs:
                continue
            try:
                glyph, metrics = glyph_add(base, s_cmap[cp], s_gs, scale, s_hmtx)
            except Exception:
                continue
            glyf.glyphs[new_name] = glyph
            hmtx.metrics[new_name] = metrics
            order.append(new_name)
            for t in cmaps:
                if t.format == 4 and cp > 0xFFFF:
                    continue
                t.cmap[cp] = new_name
            cmap12.cmap[cp] = new_name
            added[cp] = new_name
            count += 1
        per_source[label] = count
        src.close()

    finalize_glyph_tables(base, order, hmtx, added)
    return base, added, per_source


def drop_problem_tables(base, err):
    """fontTools refuses/mangles a few optional tables when glyphs are appended.
    They are rasteriser hints, not glyph programs; drop one and retry."""
    msg = str(err)
    for table, tag in (("hdmx", "hdmx"), ("LTSH", "LTSH"), ("VDMX", "VDMX"), ("PCLT", "PCLT")):
        if table in msg and tag in base:
            del base[tag]
            print(f"    dropped optional table {tag} (incompatible with appended glyphs)")
            return True
    for tag in ("hdmx", "LTSH"):
        if tag in base:
            del base[tag]
            print(f"    dropped optional table {tag} (save guard)")
            return True
    return False


def save_with_retries(font, out_path):
    for _ in range(4):
        try:
            font.save(out_path)
            return
        except (KeyError, IndexError, AssertionError, ValueError, struct.error) as err:
            if not drop_problem_tables(font, err):
                raise
    font.save(out_path)


def font_dir(prefix):
    return os.path.join(prefix, "drive_c", "windows", "Fonts")


def backup_dir(prefix):
    return os.path.join(font_dir(prefix), "backup-originals")


def discover(overrides):
    found = {}
    for label, paths in SEARCH.items():
        if overrides.get(label) is False:
            continue
        chosen = overrides.get(label) or None
        if chosen and not os.path.isfile(chosen):
            chosen = None            # explicit path missing -> fall back to defaults
        if not chosen:
            chosen = first_existing(paths)
        if chosen:
            found[label] = chosen
    return found


def cmd_patch(args):
    fdir = font_dir(args.prefix)
    if not os.path.isdir(fdir):
        sys.exit(f"not a wine prefix (no {fdir})")
    bdir = backup_dir(args.prefix)
    os.makedirs(bdir, exist_ok=True)

    sources = discover({
        "egypt": False if args.no_egypt else args.egypt,
        "runic": False if args.no_runic else args.runic,
        "emoji": False if args.no_emoji else args.emoji,
        "math": False if args.no_math else args.math,
    })
    if not sources and not args.chars:
        sys.exit("no source fonts found; pass --egypt/--runic/--emoji/--math paths")

    print("source fonts:")
    for label, path in sources.items():
        print(f"  {label:6} {path}")

    handle_extra = bool(args.chars)
    targets = args.fonts
    new_fonts = {}
    applied = set()          # source labels actually merged (for a fair verify)
    for name in targets:
        path = os.path.join(fdir, f"{name}.ttf")
        if not os.path.isfile(path):
            print(f"  skip {name}: not present")
            continue
        backup = os.path.join(bdir, f"{name}.ttf")
        pristine = backup if os.path.isfile(backup) else path
        if not os.path.isfile(backup):
            shutil.copy2(pristine, backup)  # regular file, follows symlink
            print(f"  backed up {name} -> backup-originals/{name}.ttf")

        srcs = dict(sources)
        if handle_extra:
            srcs["extra"] = None  # resolve extra chars across all sources below
        merged, added, per_source = merged_font_with_extra(
            pristine, srcs, args.chars if handle_extra else "")

        out = tempfile.NamedTemporaryFile(
            dir=fdir, prefix=f".{name}.", suffix=".tmp", delete=False)
        out.close()
        try:
            save_with_retries(merged, out.name)
        except Exception:
            merged.close()
            try:
                os.unlink(out.name)      # never leave a partial temp in Fonts/
            except OSError:
                pass
            raise
        merged.close()
        os.replace(out.name, path)  # replaces symlink itself, not its target
        os.chmod(path, 0o644)
        new_fonts[name] = (path, added, per_source)
        applied.update(k for k, v in per_source.items() if v)
        total = ", ".join(f"{k}={v}" for k, v in per_source.items() if v)
        print(f"  patched {name}: +{len(added)} glyphs ({total})")

    if not new_fonts:
        sys.exit("nothing patched")

    if args.verify:
        ok = verify(args.prefix, new_fonts, args.chars, applied)
        if not ok:
            sys.exit(1)


def merged_font_with_extra(base_path, sources, extra_chars):
    """Merge per-source ranges, then optionally resolve arbitrary characters from
    whichever source provides them."""
    if "extra" not in sources:
        return merged_font(base_path, sources, "")

    ordered = [k for k in sources if k != "extra"]
    real_sources = {k: sources[k] for k in ordered}
    base, added, per_source = merged_font(base_path, real_sources, "")

    # Extra characters: try every source in turn.
    extra_fonts = []
    for label in ordered:
        try:
            extra_fonts.append((label, load_source(real_sources[label], label)))
        except Exception:
            pass

    base_upem = base["head"].unitsPerEm
    glyf = base["glyf"]
    hmtx = base["hmtx"]
    cmaps = [t for t in base["cmap"].tables if t.isUnicode()]
    cmap12 = ensure_cmap12(base)
    order = list(base.getGlyphOrder())
    extra_added = 0
    for ch in extra_chars:
        cp = ord(ch)
        if any(t.cmap.get(cp) for t in cmaps):
            continue
        for label, src in extra_fonts:
            s_cmap = src.getBestCmap()
            if cp not in s_cmap:
                continue
            try:
                glyph, metrics = glyph_add(
                    base, s_cmap[cp], src.getGlyphSet(),
                    base_upem / src["head"].unitsPerEm, src["hmtx"])
            except Exception:
                continue
            new_name = f"byond{cp:06X}"
            glyf.glyphs[new_name] = glyph
            hmtx.metrics[new_name] = metrics
            order.append(new_name)
            for t in cmaps:
                if t.format == 4 and cp > 0xFFFF:
                    continue
                t.cmap[cp] = new_name
            cmap12.cmap[cp] = new_name
            added[cp] = new_name
            extra_added += 1
            break
    for _, src in extra_fonts:
        src.close()
    per_source["extra"] = extra_added
    finalize_glyph_tables(base, order, hmtx, added)
    return base, added, per_source


def ascii_widths(font):
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    return {
        cp: hmtx[cmap[cp]][0]
        for cp in range(0x20, 0x7F)
        if cp in cmap
    }


def verify(prefix, patched, extra_chars, applied=None):
    fdir = font_dir(prefix)
    bdir = backup_dir(prefix)
    ok = True
    # One representative codepoint per source label; only checked if that source
    # was actually merged (a missing source font is not a failure).
    samples = {
        "egypt": 0x13288,
        "emoji": 0x1F600,
        "runic": 0x16E3,
        "math": 0x1D4F0,
    }
    checks = {}
    for label, cp in samples.items():
        if applied is None or label in applied:
            checks[f"{label} {chr(cp)}"] = cp
    for ch in extra_chars or "":
        checks[f"char {ch!r}"] = ord(ch)

    print("verify:")
    for name in patched:
        path = os.path.join(fdir, f"{name}.ttf")
        backup = os.path.join(bdir, f"{name}.ttf")
        is_link = os.path.islink(path)
        f = TTFont(path, lazy=False, fontNumber=0)
        b = TTFont(backup, lazy=False, fontNumber=0) if os.path.isfile(backup) else None
        cmap = f.getBestCmap()
        missing = [label for label, cp in checks.items() if cp not in cmap]
        ascii_same = True
        if b is not None:
            ascii_same = ascii_widths(f) == ascii_widths(b)
        if b is not None:
            hint_ok = (set(HINT_TABLES) & set(b.keys())) == (set(HINT_TABLES) & set(f.keys()))
        else:
            hint_ok = True
        status = "ok" if not missing and ascii_same and hint_ok and not is_link else "FAIL"
        if status == "FAIL":
            ok = False
        print(f"  {name:8} {status}  regular_file={not is_link} ascii_widths_same={ascii_same} "
              f"hinting_tables={hint_ok} missing={missing or 'none'} glyphs={f['maxp'].numGlyphs}")
        f.close()
        if b is not None:
            b.close()
    return ok


def cmd_revert(args):
    fdir = font_dir(args.prefix)
    bdir = backup_dir(args.prefix)
    if not os.path.isdir(bdir):
        sys.exit(f"no backups at {bdir}")
    for name in BASE_FONTS:
        src = os.path.join(bdir, f"{name}.ttf")
        dst = os.path.join(fdir, f"{name}.ttf")
        if os.path.isfile(src):
            tmp = dst + ".revert.tmp"
            shutil.copy2(src, tmp)
            os.replace(tmp, dst)
            print(f"  restored {name}.ttf")
    print("reverted; restart BYOND")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prefix", required=True, help="wine prefix, e.g. ~/Games/byond")
    ap.add_argument("--fonts", default=",".join(BASE_FONTS),
                    help="comma separated base fonts (default: arial,times,tahoma,micross)")
    ap.add_argument("--egypt", help="Egyptian hieroglyph source font")
    ap.add_argument("--runic", help="Runic source font")
    ap.add_argument("--emoji", help="monochrome emoji source font (TTF outlines)")
    ap.add_argument("--math", help="math alphanumerics source (Symbola recommended)")
    ap.add_argument("--no-egypt", action="store_true")
    ap.add_argument("--no-runic", action="store_true")
    ap.add_argument("--no-emoji", action="store_true")
    ap.add_argument("--no-math", action="store_true")
    ap.add_argument("--chars", default="", help="additional characters to merge, e.g. '𓊈😀'")
    ap.add_argument("--verify", action="store_true", help="verify glyphs, ASCII widths, hinting")
    ap.add_argument("--revert", action="store_true", help="restore backup-originals")
    args = ap.parse_args()
    args.prefix = os.path.expanduser(args.prefix)
    args.fonts = [f.strip() for f in args.fonts.split(",") if f.strip()]

    if args.revert:
        cmd_revert(args)
    else:
        cmd_patch(args)


if __name__ == "__main__":
    main()
