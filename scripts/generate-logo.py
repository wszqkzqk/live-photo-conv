#!/usr/bin/env python3
"""Generate the project's vector/raster logo assets from assets/icon-master.svg.

Usage:
    python3 scripts/generate-logo.py [--font PATH] [--output PATH] [--no-icons]

Dependencies: Python 3 + fonttools + Pillow, and rsvg-convert (librsvg);
on Arch Linux: pacman -S python-fonttools python-pillow librsvg.
(Maintainer tool — the generated assets are committed; do not run this
during package builds, it downloads the font on first use.)

Outputs (all derived from the commented master assets/icon-master.svg):
  - assets/icon.svg  MINIFIED master copy (comments/blank lines stripped);
                     this is what programs embed (GResource, Android, ...)
  - assets/logo.svg  banner (icon + wordmark), also minified
  - assets/icon.png  256x256 render
  - assets/icon.ico  Windows icon, 256..16 px, largest first

The wordmark letterforms are baked to <path> outlines (font-independent, no
<text> elements): "Live Photo" uses **Nunito** (rounded), "Converter" uses
**Jost** (a faithful Futura clone) — both licensed under the SIL Open Font
License 1.1, compatible with this GPL project. Unless --font/--lp-font are
given, the variable fonts are downloaded once from the google/fonts GitHub
repo and cached in the system temp dir; the Medium instance (wght=500) of
each is used.

Layout (icon transform, cap heights, baselines, tracking, gradient stops,
Converter blue) is fixed by the constants below, fitted to the historical
raster banner (795x447).
"""

import argparse
import re
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

from fontTools.ttLib import TTFont

# ---------------------------------------------------------------- constants

REPO_ROOT = Path(__file__).resolve().parent.parent
MASTER_SVG = REPO_ROOT / 'assets' / 'icon-master.svg'
ICON_SVG = REPO_ROOT / 'assets' / 'icon.svg'
OUT_SVG = REPO_ROOT / 'assets' / 'logo.svg'
OUT_PNG = REPO_ROOT / 'assets' / 'icon.png'
OUT_ICO = REPO_ROOT / 'assets' / 'icon.ico'
ICO_SIZES = (256, 128, 64, 48, 32, 24, 16)

JOST_URL = ('https://raw.githubusercontent.com/google/fonts/'
            'main/ofl/jost/Jost%5Bwght%5D.ttf')
LP_FONT_URL = ('https://raw.githubusercontent.com/google/fonts/'
               'main/ofl/nunito/Nunito%5Bwght%5D.ttf')
FONT_WEIGHT = 500  # Medium

# icon placement in the 795x447 banner (fitted to the original raster)
ICON_TX, ICON_TY, ICON_S = 56.8, 106.8, 0.955

# wordmark: text, cap height, baseline y, ink left/right edges
LP_TEXT, LP_CAP, LP_BASE, LP_LEFT, LP_RIGHT = 'Live Photo', 68.0, 225.0, 342.0, 723.0
CV_TEXT, CV_CAP, CV_BASE, CV_LEFT, CV_RIGHT = 'Converter', 48.0, 292.0, 339.0, 623.0
CV_COLOR = '#25aff0'

# "Live Photo" diagonal gradient, stops sampled from the original raster
WORD_GRAD = ((342.0, 156.0, 723.0, 225.0), (
    (0.0, '#268cec'), (0.15, '#3481e4'), (0.32, '#3b6ed3'),
    (0.48, '#3a6dd8'), (0.62, '#495fd2'), (0.75, '#6e50c2'),
    (0.88, '#9241b1'), (1.0, '#c93496'),
))

DOT_SCALE = 1.15  # enlarge the 'i' tittle to match the original's larger dot


# ------------------------------------------------------------- font loading

def load_font(path):
    font = TTFont(str(path))
    if 'fvar' in font:
        from fontTools.varLib.instancer import instantiateVariableFont
        instantiateVariableFont(font, {'wght': FONT_WEIGHT}, inplace=True)
    return font


def fetch_font(url, cache_name):
    cache = Path(tempfile.gettempdir()) / cache_name
    if not cache.exists():
        import socket
        socket.setdefaulttimeout(30)
        print(f'downloading font (OFL) from {url}')
        for attempt in (1, 2):
            try:
                urllib.request.urlretrieve(url, cache)
                break
            except Exception:
                cache.unlink(missing_ok=True)
                if attempt == 2:
                    raise
    return load_font(cache)


# ------------------------------------------------------- glyph outline pens

class ContourPen:
    """Records a glyph as separate contours of (cmd, flat-points), with
    TrueType multi-point qCurveTo decomposed into single quadratic segments
    (implied on-curve midpoints inserted)."""

    def __init__(self, glyph_set):
        self.glyph_set = glyph_set
        self.contours = []
        self.cur = None
        self.pos = None      # current point
        self.start = None    # contour start point

    def moveTo(self, p):
        self.cur = [('M', (p[0], p[1]))]
        self.contours.append(self.cur)
        self.pos = self.start = (p[0], p[1])

    def lineTo(self, p):
        self.cur.append(('L', (p[0], p[1])))
        self.pos = (p[0], p[1])

    def curveTo(self, p1, p2, p3):
        self.cur.append(('C', (p1[0], p1[1], p2[0], p2[1], p3[0], p3[1])))
        self.pos = (p3[0], p3[1])

    def qCurveTo(self, *pts):
        pts = list(pts)
        end = self.start if pts[-1] is None else pts[-1]
        ctrls = pts if pts[-1] is None else pts[:-1]
        for i, c in enumerate(ctrls):
            if i < len(ctrls) - 1:
                nxt = ctrls[i + 1]
                e = ((c[0] + nxt[0]) / 2, (c[1] + nxt[1]) / 2)
            else:
                e = end
            self.cur.append(('Q', (c[0], c[1], e[0], e[1])))
        self.pos = end

    def closePath(self):
        self.cur.append(('Z', None))
        self.pos = self.start

    def endPath(self):
        pass

    def addComponent(self, glyph_name, transformation):
        from fontTools.pens.transformPen import TransformPen
        sub = ContourPen(self.glyph_set)
        self.glyph_set[glyph_name].draw(TransformPen(sub, transformation))
        self.contours.extend(sub.contours)


def get_contours(glyph_set, glyph_name):
    pen = ContourPen(glyph_set)
    glyph_set[glyph_name].draw(pen)
    return pen.contours


def contour_bbox(contour):
    xs, ys = [], []
    for cmd, pts in contour:
        if pts:
            xs.extend(pts[0::2])
            ys.extend(pts[1::2])
    return min(xs), min(ys), max(xs), max(ys)


def scale_dot(contours, xheight, factor):
    """Scale the 'i' tittle (the contour entirely above x-height) about
    its own center."""
    idx = None
    for i, contour in enumerate(contours):
        _, y0, _, _ = contour_bbox(contour)
        if y0 > xheight + 40:
            idx = i
            break
    if idx is None:
        return contours
    x0, y0, x1, y1 = contour_bbox(contours[idx])
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    nc = []
    for cmd, pts in contours[idx]:
        if pts is None:
            nc.append((cmd, pts))
            continue
        xy = list(pts)
        for i in range(0, len(xy), 2):
            xy[i] = cx + (xy[i] - cx) * factor
            xy[i + 1] = cy + (xy[i + 1] - cy) * factor
        nc.append((cmd, tuple(xy)))
    return contours[:idx] + [nc] + contours[idx + 1:]


# --------------------------------------------------------------- wordmark

def minify_svg(src):
    """Strip XML comments and blank lines (used for the embedded icon)."""
    src = re.sub(r'<!--.*?-->', '', src, flags=re.S)
    return '\n'.join(ln for ln in src.splitlines() if ln.strip())


def derive_icons():
    """Write the minified assets/icon.svg and render icon.png/icon.ico."""
    from PIL import Image
    tmp = Path(tempfile.gettempdir())
    ICON_SVG.write_text(minify_svg(MASTER_SVG.read_text()) + '\n')
    print(f'wrote {ICON_SVG} (minified)')
    subprocess.run(['rsvg-convert', '-w', '256', '-h', '256',
                    str(MASTER_SVG), '-o', str(OUT_PNG)], check=True)
    imgs = [Image.open(OUT_PNG)]
    for s in ICO_SIZES[1:]:
        p = tmp / f'live-photo-conv-ico-{s}.png'
        subprocess.run(['rsvg-convert', '-w', str(s), '-h', str(s),
                        str(MASTER_SVG), '-o', str(p)], check=True)
        imgs.append(Image.open(p))
    imgs[0].save(OUT_ICO, format='ICO',
                 sizes=[(i.width, i.height) for i in imgs],
                 append_images=imgs[1:])
    print(f'wrote {OUT_PNG} and {OUT_ICO}')

def build_line(font, text, cap_px, baseline, left, right):
    """Lay out one wordmark line: tweaked glyph outlines baked into absolute
    SVG path data. Letter tracking is bisected so the ink lands exactly on
    the [left, right] edges of the original banner."""
    upm = font['head'].unitsPerEm
    cap = font['OS/2'].sCapHeight
    xh = font['OS/2'].sxHeight
    s = (cap_px * upm / cap) / upm
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    ktab = font['kern'].kernTables[0].kernTable if 'kern' in font else {}

    glyphs = {}
    for ch in set(text):
        gname = cmap[ord(ch)]
        cont = get_contours(glyph_set, gname)
        if gname == 'i':
            cont = scale_dot(cont, xh, DOT_SCALE)
        glyphs[gname] = cont

    def layout(track_em, x_shift=0.0):
        x = 0.0
        prev = None
        placed = []
        for ch in text:
            gname = cmap[ord(ch)]
            if prev is not None:
                x += ktab.get((prev, gname), 0)
            placed.append((gname, x))
            x += glyph_set[gname].width + track_em * upm
            prev = gname
        full = []
        bx = [1e9, -1e9]
        for gname, dx in placed:
            parts = []
            for contour in glyphs[gname]:
                for cmd, pts in contour:
                    if pts is None:
                        parts.append('Z')
                        continue
                    xy = list(pts)
                    for i in range(0, len(xy), 2):
                        xy[i] = x_shift + (dx + xy[i]) * s
                        xy[i + 1] = baseline - xy[i + 1] * s
                        bx[0] = min(bx[0], xy[i])
                        bx[1] = max(bx[1], xy[i])
                    parts.append(cmd + ','.join('%.1f' % v for v in xy))
            full.append(''.join(parts))
        return ' '.join(full), bx

    target_w = right - left
    lo, hi = -0.3, 0.1
    for _ in range(50):
        mid = (lo + hi) / 2
        _, bx = layout(mid)
        if bx[1] - bx[0] > target_w:
            hi = mid
        else:
            lo = mid
    track = (lo + hi) / 2
    _, bx = layout(track)
    d, bx = layout(track, left - bx[0])
    print(f"  '{text}': tracking {track:+.4f} em, ink x {bx[0]:.1f}..{bx[1]:.1f}")
    return d


# ------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--font', help='path to a Jost TTF (skip the download)')
    ap.add_argument('--lp-font',
                    help='path to a TTF for the "Live Photo" line only '
                         '(default: download Nunito)')
    ap.add_argument('--output', default=str(OUT_SVG),
                    help='output SVG path (default: assets/logo.svg)')
    ap.add_argument('--no-icons', action='store_true',
                    help='do not re-derive icon.png/icon.ico')
    args = ap.parse_args()

    font = load_font(args.font) if args.font else fetch_font(
        JOST_URL, 'live-photo-conv-jost.ttf')
    lp_font = load_font(args.lp_font) if args.lp_font else fetch_font(
        LP_FONT_URL, 'live-photo-conv-nunito.ttf')

    lp_d = build_line(lp_font, LP_TEXT, LP_CAP, LP_BASE, LP_LEFT, LP_RIGHT)
    cv_d = build_line(font, CV_TEXT, CV_CAP, CV_BASE, CV_LEFT, CV_RIGHT)

    src = minify_svg(MASTER_SVG.read_text())
    defs = re.search(r'<defs>(.*?)</defs>', src, re.S).group(1).strip('\n')
    body = re.search(r'</defs>(.*?)</svg>', src, re.S).group(1).strip('\n')
    indent = lambda block: '\n'.join('    ' + ln for ln in block.splitlines() if ln.strip())

    (gx1, gy1, gx2, gy2), stops = WORD_GRAD
    stops_xml = '\n'.join(f'        <stop offset="{o}" stop-color="{c}"/>'
                          for o, c in stops)

    svg = f'''<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 795 447">
  <defs>
    <!-- wordmark "Live Photo" diagonal gradient (sampled from original) -->
    <linearGradient id="gWord" gradientUnits="userSpaceOnUse" x1="{gx1}" y1="{gy1}" x2="{gx2}" y2="{gy2}">
{stops_xml}
    </linearGradient>
{indent(defs)}
  </defs>

  <!-- ===== icon (embedded from assets/icon.svg, scaled) ===== -->
  <g transform="translate({ICON_TX},{ICON_TY}) scale({ICON_S})">
{indent(body)}
  </g>

  <!-- ===== wordmark (font-independent outlines; Nunito/Jost Medium, OFL) ===== -->
  <!-- "Live Photo": larger, blue-to-magenta gradient -->
  <path fill="url(#gWord)" d="{lp_d}"/>
  <!-- "Converter": smaller, solid blue -->
  <path fill="{CV_COLOR}" d="{cv_d}"/>
</svg>
'''
    out = Path(args.output)
    out.write_text(minify_svg(svg) + '\n')
    print(f'wrote {out}')

    if not args.no_icons:
        derive_icons()


if __name__ == '__main__':
    main()
