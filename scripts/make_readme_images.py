#!/usr/bin/env python3
"""Draws the README mock-ups of EzWoW - Utility Bar (docs/images/ui_*.png, settings_*.png).

The utility bar and the settings window are rebuilt from the sizes, coordinates, colours
and strings in the addon code (UI/ToolbarFrame.lua, UI/OptionsWindow.lua, Core/Init.lua
Style and DEFAULTS, Core/Locales.lua), in game pixels x scale. Icons are simplified
drawings; items are examples.

usage: python scripts/make_readme_images.py .
Renders with a local headless Chrome (set CHROME=<path> if it is not found).
"""
import base64
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

PAGE_W = 1600

# ---------------------------------------------------------------------------
# Small readers for the Lua code
# ---------------------------------------------------------------------------


def read(root, rel):
    return (root / rel).read_text(encoding="utf-8")


def find_file(root, *names):
    """First existing file of names (case-insensitive on every system)."""
    for name in names:
        p = root / name
        if p.exists():
            return p
        parent = p.parent
        if parent.exists():
            for q in parent.iterdir():
                if q.name.lower() == p.name.lower():
                    return q
    raise FileNotFoundError(names)


def rgb_list(body):
    return [float(v) for v in body.split(",") if v.strip()]


def lua_table(src, start_pattern):
    """Text of the Lua table that starts at start_pattern (balanced braces)."""
    m = re.search(start_pattern, src)
    if not m:
        raise ValueError(start_pattern)
    i = src.index("{", m.start())
    depth = 0
    for j in range(i, len(src)):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[i + 1:j]
    raise ValueError("unbalanced " + start_pattern)


def lua_strings(block):
    """key = "value" pairs of a Lua table body (plain keys and ["keys"])."""
    out = {}
    for k1, k2, v in re.findall(r'(?:^|[\s,{])(?:(\w+)|\["((?:[^"\\]|\\.)*)"\])\s*=\s*"((?:[^"\\]|\\.)*)"', block, re.M):
        out[k1 or k2] = unlua(v)
    return out


def unlua(v):
    return v.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def toc_version(root):
    for p in root.glob("*.toc"):
        m = re.search(r"^## Version:\s*(\S+)", p.read_text(encoding="utf-8"), re.M)
        if m:
            return m.group(1)
    return ""


def css(c, alpha=None, mul=1.0):
    r, g, b = (round(min(1, v * mul) * 255) for v in c[:3])
    a = alpha if alpha is not None else (c[3] if len(c) > 3 else 1)
    return f"rgba({r},{g},{b},{a:.2f})"


def hexc(c):
    return "#%02x%02x%02x" % tuple(round(v * 255) for v in c[:3])


def esc(s):
    return html.escape(str(s), quote=False)


def wow(s):
    """Game text -> HTML: |cffRRGGBB..|r colours, |n / \\n line breaks, icons dropped."""
    s = esc(s)
    s = re.sub(r"\|T[^|]*\|t", "", s)
    s = re.sub(r"\|A[^|]*\|a", "", s)
    out, depth = [], 0
    pos = 0
    for m in re.finditer(r"\|c[0-9a-fA-F]{2}([0-9a-fA-F]{6})|\|r", s):
        out.append(s[pos:m.start()])
        if m.group(0) == "|r":
            if depth:
                out.append("</span>")
                depth -= 1
        else:
            out.append(f'<span style="color:#{m.group(1)}">')
            depth += 1
        pos = m.end()
    out.append(s[pos:])
    out.append("</span>" * depth)
    return "".join(out).replace("|n", "<br>").replace("\n", "<br>")


# ---------------------------------------------------------------------------
# Page parts (game px x S -> page px)
# ---------------------------------------------------------------------------
S = 1.3


def px(v):
    return f"{v * S:.2f}px"


OUTLINE = "text-shadow:-1px 0 #000,1px 0 #000,0 -1px #000,0 1px #000,0 0 2px #000;"
SHADOW = "text-shadow:1px 1px 0 #000,0 0 2px rgba(0,0,0,.8);"

# client colours used by several mock-ups
QUALITY = {0: "#9d9d9d", 1: "#ffffff", 2: "#1eff00", 3: "#0070dd", 4: "#a335ee", 5: "#ff8000"}
CLASS_HEX = {"WARRIOR": "#c69b6d", "PALADIN": "#f48cba", "HUNTER": "#aad372", "ROGUE": "#fff468", "PRIEST": "#ffffff",
             "SHAMAN": "#0070dd", "MAGE": "#3fc7eb", "WARLOCK": "#8788ee", "DRUID": "#ff7c0a"}
GOLD = "#ffd100"

THEME = {
    "bg": (0.071, 0.094, 0.122, 0.97), "bgSub": (0.114, 0.157, 0.192, 0.96), "border": (0.204, 0.298, 0.357, 1),
    "text": (0.929, 0.957, 0.969, 1), "muted": (0.655, 0.725, 0.773, 1), "accent": (0.5, 0.8, 0.9, 1),
}


def page_css(call):
    return f"""
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ width: {PAGE_W}px; overflow: hidden; }}
body {{ background: #0e141a; font-family: 'Noto Sans KR','Malgun Gothic',sans-serif; color: #edf4f7; position: relative; }}
.sky {{ position: absolute; left: 0; top: 0; width: {PAGE_W}px; height: 100%;
  background: radial-gradient(ellipse at 25% 0%, #1d2b38 0%, #151f28 45%, #10171d 75%, #0c1115 100%); }}
.hills {{ position: absolute; left: 0; bottom: 0; width: {PAGE_W}px; height: 260px; }}
.page {{ position: relative; padding: 34px 50px 0; }}
h1 {{ color: {call}; font-size: 40px; font-weight: 700; letter-spacing: .3px; display: flex; align-items: center; gap: 14px; }}
h1 .badge {{ font-size: 15px; background: {call}; color: #10161c; padding: 2px 9px; border-radius: 5px; }}
.lead {{ color: #d5dde2; font-size: 19px; margin-top: 6px; }}
.abs {{ position: absolute; }}
.t {{ position: absolute; white-space: nowrap; line-height: 1.15; }}
.call {{ position: absolute; width: 30px; height: 30px; border-radius: 50%; background: {call}; color: #10161c; font-weight: 700;
  font-size: 16px; display: flex; align-items: center; justify-content: center; border: 2px solid #10161c; box-shadow: 0 0 0 2px {call}55; z-index: 60; }}
.notes {{ position: absolute; }}
.note {{ display: flex; gap: 12px; margin-bottom: 11px; font-size: 16px; line-height: 1.5; color: #dfe6ea; }}
.note .n {{ flex: none; width: 28px; height: 28px; border-radius: 50%; background: {call}; color: #10161c; font-weight: 700;
  font-size: 15px; display: flex; align-items: center; justify-content: center; }}
.note b {{ color: #fff; }}
.foot {{ position: absolute; color: #7d8d98; font-size: 13.5px; line-height: 1.5; }}
.fit {{ display: inline-block; white-space: nowrap; }}
.tip {{ position: absolute; z-index: 30; }}
.tip .row {{ display: flex; justify-content: space-between; gap: 18px; white-space: nowrap; }}
"""


HILLS = ('<svg class="hills" viewBox="0 0 1600 260" preserveAspectRatio="none">'
         '<path d="M0 150 C 220 70 420 90 640 140 C 860 190 1060 60 1300 80 C 1440 92 1540 120 1600 130 V260 H0 Z" fill="#141c23" opacity=".9"/>'
         '<path d="M0 210 C 260 160 520 170 800 205 C 1080 240 1340 170 1600 190 V260 H0 Z" fill="#0b1014"/></svg>')

FIT_JS = """
<script>
document.querySelectorAll('[data-fit]').forEach(function (e) {
  var max = parseFloat(e.dataset.fit), min = parseFloat(e.dataset.min || 8);
  var fs = parseFloat(getComputedStyle(e).fontSize);
  while (e.scrollWidth > max && fs > min) { fs -= 0.25; e.style.fontSize = fs + 'px'; }
  if (e.scrollWidth > max) { e.style.maxWidth = max + 'px'; e.style.overflow = 'hidden'; e.style.textOverflow = 'ellipsis'; }
});
// place the footnote under the lowest element, then record the page height
var bottom = 0;
document.querySelectorAll('.page *, body > .abs, body > .notes, body > .call, body > .tip').forEach(function (e) {
  var r = e.getBoundingClientRect(); if (r.height > 0 && r.bottom > bottom) bottom = r.bottom;
});
var foot = document.querySelector('.foot');
if (foot) { foot.style.top = (bottom + 26) + 'px'; bottom = foot.getBoundingClientRect().bottom; }
document.body.setAttribute('data-h', Math.ceil(bottom + 34));
document.body.style.height = Math.ceil(bottom + 34) + 'px';
</script>
"""


def box(x, y, w, h, style="", inner=""):
    return f'<div class="abs" style="left:{px(x)};top:{px(y)};width:{px(w)};height:{px(h)};{style}">{inner}</div>'


def text(x, y, s, size, color="#fff", anchor="left", style="", fit=None, shadow=SHADOW):
    """Font string; y is the vertical centre (game px)."""
    tr = {"left": "translate(0,-50%)", "right": "translate(-100%,-50%)", "center": "translate(-50%,-50%)"}[anchor]
    inner = s if fit is None else f'<span class="fit" data-fit="{fit * S:.1f}" data-min="{size * 0.7 * S:.1f}">{s}</span>'
    return (f'<div class="t" style="left:{px(x)};top:{px(y)};font-size:{px(size)};color:{color};'
            f'transform:{tr};{shadow}{style}">{inner}</div>')


def text_top(x, y, s, size, color="#fff", width=None, style="", shadow=SHADOW):
    """Font string anchored at its top-left (TOPLEFT points)."""
    w = f"width:{px(width)};white-space:normal;" if width else ""
    return (f'<div class="t" style="left:{px(x)};top:{px(y)};font-size:{px(size)};color:{color};line-height:1.3;'
            f'{w}{shadow}{style}">{s}</div>')


class Window:
    """A flat EzWoW style window: header strip, accent line, icon, title, sub title, close box."""

    def __init__(self, th, w, h, title, sub="", icon=None, header=56, close=22, close_off=10, title_color=None):
        self.th, self.w, self.h = th, w, h
        self.p = []
        acc = css(th["accent"], 1)
        if header:
            self.p.append(box(1, 1, w - 2, header, f"background:{css(th['bgSub'], .98)}"))
            self.p.append(box(1, header - 1, w - 2, 2, f"background:{acc}"))
            if icon:
                self.p.append(f'<img class="abs" src="{icon}" style="left:{px(14)};top:{px(14)};width:{px(28)};height:{px(28)}">')
            self.p.append(text_top(48, 10, esc(title), 16, title_color or acc))
            if sub:
                self.p.append(text_top(48, 32, sub, 10, css(th["muted"]), width=w - 120))
            if close:
                self.button(w - 1 - close_off - close, close_off + 1, close, close, "X", size=12)

    def add(self, s):
        self.p.append(s)

    def section(self, x, y, label, width=None, line_dy=18):
        acc = css(self.th["accent"], 1)
        self.p.append(text_top(x, y, label, 13, acc))
        w = width if width else self.w - x - 20
        self.p.append(box(x, y + line_dy, w, 1, f"background:{css(self.th['border'], .85)}"))

    def check(self, x, y, label, on, size=24, label_w=180, font=12, disabled=False, color=None):
        mark = (f'<div class="t" style="left:{px(size * 0.1)};top:{px(-size * 0.12)};font-size:{px(size * 0.9)};color:#ffd200;'
                f'text-shadow:0 0 1px #000,1px 1px 0 #6b4a00">&#10004;</div>') if on else ""
        b = size * 0.72
        o = (size - b) / 2
        alpha = ";opacity:.55" if disabled else ""
        self.p.append(box(x + o, y + o, b, b, f"border:1px solid #6d6a5d;background:#191919;border-radius:2px;overflow:visible{alpha}", mark))
        col = color or css(self.th["muted"] if disabled else self.th["text"])
        self.p.append(text(x + size + 4, y + size / 2, label, font, col, fit=label_w))

    def radio(self, x, y, label, on, size=22, label_w=150, font=12):
        dot = box(size * .32, size * .32, size * .36, size * .36, "border-radius:50%;background:#ffd200;box-shadow:0 0 3px #ffb000") if on else ""
        self.p.append(box(x + 2, y + 2, size - 4, size - 4, "border:1px solid #7a7a7a;border-radius:50%;background:#151515", dot))
        self.p.append(text(x + size + 4, y + size / 2, label, font, css(self.th["text"]), fit=label_w))

    def button(self, x, y, w, h, label, accent=False, size=12, color=None, bg=None, border=None):
        th = self.th
        bgc = bg or css(th["bgSub"])
        bd = border or (css(th["accent"]) if accent else css(th["border"]))
        col = color or (css(th["accent"]) if accent else css(th["text"]))
        self.p.append(box(x, y, w, h, f"background:{bgc};border:1px solid {bd};display:flex;align-items:center;justify-content:center",
                          f'<span class="fit" data-fit="{(w - 10) * S:.1f}" data-min="{size * .7 * S:.1f}" '
                          f'style="font-size:{px(size)};color:{col};{SHADOW}">{label}</span>'))

    def stepper(self, x, y, label, value, minus_dx, plus_dx, bw=25, bh=25, label_dy=6, label_w=84, value_color=None, font=12):
        self.p.append(text_top(x, y + label_dy, f'<span class="fit" data-fit="{label_w * S:.1f}" data-min="{9 * S:.1f}">{label}</span>',
                               font, css(self.th["text"])))
        self.button(x + minus_dx, y, bw, bh, "-", size=14)
        self.button(x + plus_dx, y, bw, bh, "+", size=14)
        cx = x + minus_dx + bw / 2 + (plus_dx - minus_dx) / 2
        self.p.append(text(cx, y + bh / 2, value, font, value_color or css(self.th["text"]), anchor="center"))

    def html(self, ox, oy, extra_style=""):
        th = self.th
        return (f'<div class="abs" style="left:{ox}px;top:{oy}px;width:{px(self.w)};height:{px(self.h)};background:{css(th["bg"])};'
                f'border:1px solid {css(th["border"])};box-shadow:0 10px 40px rgba(0,0,0,.45);{extra_style}">' + "".join(self.p) + "</div>")


def tooltip(x, y, lines, border="#344c5b", width=None, pad=10, bg="rgba(18,24,31,.95)", gloss=True, bar=None, font=12,
            title_size=14, left_pad=0, z=30, extra=""):
    """A tooltip card at page px (x, y). lines: list of str | (left, right) | ("gap",); first line is the title.
    Strings are already HTML. bar: (fraction, colour, label) drawn along the bottom."""
    rows = []
    for i, ln in enumerate(lines):
        fs = title_size if i == 0 else font
        if ln == ("gap",):
            rows.append(f'<div style="height:{px(font * .7)}"></div>')
        elif isinstance(ln, tuple):
            rows.append(f'<div class="row" style="font-size:{px(fs)};line-height:1.42"><span>{ln[0]}</span><span>{ln[1]}</span></div>')
        else:
            rows.append(f'<div style="font-size:{px(fs)};line-height:1.42;white-space:nowrap">{ln}</div>')
    w = f"width:{px(width)};" if width else ""
    glo = (f'<div class="abs" style="left:0;right:0;top:0;height:{px(26)};background:linear-gradient(to bottom,rgba(255,255,255,.07),'
           f'rgba(255,255,255,0))"></div>') if gloss else ""
    bar_h = ""
    bottom_pad = pad
    if bar:
        frac, col, label = bar
        bottom_pad = pad + 10
        bar_h = (f'<div class="abs" style="left:{px(1)};right:{px(1)};bottom:{px(1)};height:{px(8)};background:rgba(0,0,0,.6)">'
                 f'<div class="abs" style="left:0;top:0;bottom:0;width:{frac * 100:.1f}%;background:{col}"></div>'
                 f'<div class="abs" style="inset:0;display:flex;align-items:center;justify-content:center;font-size:{px(7.5)};color:#fff;{OUTLINE}">{label}</div></div>')
    return (f'<div class="tip" style="left:{x:.0f}px;top:{y:.0f}px;{w}background:{bg};border:1px solid {border};'
            f'padding:{px(pad)} {px(pad)} {px(bottom_pad)} {px(pad + left_pad)};{SHADOW}z-index:{z};{extra}">'
            f'{glo}{"".join(rows)}{bar_h}</div>')


def callouts(points):
    return "".join(f'<div class="call" style="left:{x - 15:.0f}px;top:{y - 15:.0f}px">{i}</div>' for i, (x, y) in enumerate(points, 1))


def notes_html(notes, start=1):
    return "".join(f'<div class="note"><span class="n">{start + i}</span><div><b>{esc(a)}</b> — {b}</div></div>'
                   for i, (a, b) in enumerate(notes))


def notes_block(x, y, w, notes, start=1):
    return f'<div class="notes" style="left:{x:.0f}px;top:{y:.0f}px;width:{w:.0f}px">{notes_html(notes, start)}</div>'


def heading(title, lead, badge=None):
    b = f' <span class="badge">{esc(badge)}</span>' if badge else ""
    return f'<div class="page"><h1>{esc(title)}{b}</h1><div class="lead">{lead}</div></div>'


def icon_data(path):
    return "data:image/png;base64," + base64.b64encode(Path(path).read_bytes()).decode()


# simple square icon art (stands in for game icons)
ICON_ART = {
    "potion": ("#3a1418", '<path d="M40 14 H60 V34 C76 40 82 54 82 64 A32 26 0 0 1 18 64 C18 54 24 40 40 34 Z" fill="#d8323c"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "mana": ("#121e3e", '<path d="M40 14 H60 V34 C76 40 82 54 82 64 A32 26 0 0 1 18 64 C18 54 24 40 40 34 Z" fill="#3d7cf0"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "elixir": ("#14301e", '<path d="M44 12 H56 V40 L74 80 H26 L44 40 Z" fill="#5fd05a"/><rect x="40" y="8" width="20" height="8" fill="#b08860"/>'),
    "stone": ("#1c2a1c", '<path d="M50 12 L80 40 L62 86 H38 L20 40 Z" fill="#62e07a"/><path d="M50 12 L62 40 L50 86 L38 40 Z" fill="#a8f5b4"/>'),
    "helm": ("#2a2a30", '<path d="M18 64 C18 30 34 16 50 16 C66 16 82 30 82 64 L72 80 H28 Z" fill="#a8adb8"/><rect x="30" y="50" width="40" height="10" fill="#2a2a30"/>'),
    "glove": ("#2a2420", '<path d="M30 86 V44 L26 22 H36 L40 40 V16 H48 V40 V12 H56 V40 V16 H64 V44 L74 34 L80 40 L66 62 V86 Z" fill="#b58a5a"/>'),
    "ring": ("#2a2418", '<circle cx="50" cy="56" r="24" fill="none" stroke="#e8c050" stroke-width="10"/><path d="M42 26 L50 14 L58 26 L50 34 Z" fill="#6ad0ff"/>'),
    "sword": ("#202830", '<path d="M70 14 L84 16 L86 30 L44 72 L30 58 Z" fill="#cfd8e0"/><path d="M26 54 L46 74 L40 80 L20 60 Z" fill="#b08040"/><path d="M28 72 L18 82" stroke="#806030" stroke-width="8"/>'),
    "food": ("#3a2412", '<ellipse cx="50" cy="58" rx="30" ry="20" fill="#c87838"/><circle cx="64" cy="40" r="12" fill="#f0e0c0"/>'),
    "drink": ("#14283a", '<path d="M30 20 H70 L64 84 H36 Z" fill="#8fd0f0" opacity=".85"/><rect x="30" y="20" width="40" height="10" fill="#e0f4ff"/>'),
    "bandage": ("#2c2c2c", '<rect x="18" y="38" width="64" height="26" rx="12" fill="#e8e0d0" transform="rotate(-35 50 50)"/>'),
    "hearth": ("#1a2a3a", '<circle cx="50" cy="50" r="26" fill="#7fd0ff"/><circle cx="50" cy="50" r="12" fill="#e0f6ff"/>'),
    "pet": ("#2a2018", '<ellipse cx="50" cy="62" rx="26" ry="18" fill="#d8a060"/><circle cx="66" cy="38" r="14" fill="#d8a060"/><path d="M60 26 L62 14 L70 24 Z M72 28 L80 18 L80 32 Z" fill="#a06a30"/><circle cx="70" cy="38" r="3" fill="#201008"/>'),
    "pick": ("#2a2a2a", '<path d="M20 30 C40 14 64 14 82 30 L76 36 C62 26 42 26 26 36 Z" fill="#bcc4cc"/><rect x="46" y="28" width="8" height="58" fill="#8a6030"/>'),
    "herb": ("#1c3018", '<path d="M50 86 V40" stroke="#5a9040" stroke-width="6"/><ellipse cx="36" cy="44" rx="14" ry="8" fill="#70c050" transform="rotate(-30 36 44)"/><ellipse cx="64" cy="40" rx="14" ry="8" fill="#70c050" transform="rotate(30 64 40)"/><circle cx="50" cy="28" r="10" fill="#e070d0"/>'),
    "fire": ("#3a1a0a", '<path d="M50 12 C62 34 80 44 70 70 A22 22 0 0 1 30 70 C22 50 40 40 42 26 C48 36 50 30 50 12 Z" fill="#ff8a2a"/><path d="M50 46 C58 58 62 64 56 76 A10 10 0 0 1 42 74 C40 64 48 58 50 46 Z" fill="#ffe070"/>'),
    "holy": ("#3a3010", '<circle cx="50" cy="50" r="20" fill="#ffe680"/><path d="M50 10 V30 M50 70 V90 M10 50 H30 M70 50 H90 M22 22 L36 36 M64 64 L78 78 M22 78 L36 64 M64 36 L78 22" stroke="#ffe680" stroke-width="6"/>'),
    "shield": ("#1e2836", '<path d="M50 10 L84 22 C84 56 72 78 50 90 C28 78 16 56 16 22 Z" fill="#7aa4d8"/><path d="M50 22 L72 30 C72 54 64 70 50 78 Z" fill="#b8d4f4"/>'),
    "shadow": ("#1e1430", '<circle cx="50" cy="50" r="28" fill="#8a5ad8"/><circle cx="50" cy="50" r="14" fill="#2a1840"/>'),
    "frost": ("#14283a", '<path d="M50 12 V88 M17 31 L83 69 M17 69 L83 31" stroke="#bfe6ff" stroke-width="9" stroke-linecap="round"/>'),
    "nature": ("#203a1c", '<path d="M50 84 C20 70 18 36 50 14 C82 36 80 70 50 84 Z" fill="#7cd060"/><path d="M50 84 V30" stroke="#2a5a1c" stroke-width="5"/>'),
    "arcane": ("#2a1840", '<path d="M50 14 L58 42 L86 50 L58 58 L50 86 L42 58 L14 50 L42 42 Z" fill="#d79cff"/>'),
    "claw": ("#3a1414", '<path d="M25 80 L45 20 M45 82 L62 22 M65 84 L80 28" stroke="#ff6a5a" stroke-width="9" stroke-linecap="round"/>'),
    "bear": ("#2e2014", '<circle cx="50" cy="56" r="26" fill="#8a5a30"/><circle cx="30" cy="30" r="10" fill="#8a5a30"/><circle cx="70" cy="30" r="10" fill="#8a5a30"/><circle cx="42" cy="52" r="4" fill="#1a0a00"/><circle cx="58" cy="52" r="4" fill="#1a0a00"/>'),
    "cat": ("#3a2a1a", '<path d="M24 82 L24 34 L36 18 L44 34 L56 34 L64 18 L76 34 L76 82 Z" fill="#c9965a"/><circle cx="40" cy="50" r="5" fill="#2a1a0a"/><circle cx="60" cy="50" r="5" fill="#2a1a0a"/>'),
    "heal": ("#14301e", '<rect x="40" y="18" width="20" height="64" fill="#8cf08c"/><rect x="18" y="40" width="64" height="20" fill="#8cf08c"/>'),
    "book": ("#2a1e14", '<rect x="20" y="16" width="60" height="70" rx="4" fill="#8a4a2a"/><rect x="28" y="16" width="6" height="70" fill="#5a2a14"/><rect x="40" y="30" width="30" height="6" fill="#e8c890"/>'),
    "scroll": ("#2e2616", '<rect x="24" y="22" width="52" height="56" fill="#e8d8a8"/><rect x="18" y="16" width="64" height="10" rx="5" fill="#b89860"/><rect x="18" y="74" width="64" height="10" rx="5" fill="#b89860"/><path d="M34 40 H66 M34 52 H66 M34 64 H56" stroke="#8a6a3a" stroke-width="4"/>'),
    "flask": ("#2a1a3a", '<circle cx="50" cy="60" r="24" fill="#b070f0"/><rect x="42" y="14" width="16" height="26" fill="#b070f0"/><rect x="38" y="10" width="24" height="8" fill="#b08860"/>'),
    "thread": ("#1a2840", '<rect x="34" y="16" width="32" height="68" rx="6" fill="#d8b070"/><rect x="30" y="30" width="40" height="40" fill="#3a78d8"/>'),
    "hammer": ("#2a2a2a", '<rect x="22" y="18" width="56" height="22" rx="3" fill="#a0a8b0"/><rect x="45" y="40" width="10" height="46" fill="#8a6030"/>'),
    "fish": ("#10304a", '<path d="M14 50 C30 26 62 26 74 50 C62 74 30 74 14 50 Z" fill="#7fb8e0"/><path d="M74 50 L90 34 V66 Z" fill="#7fb8e0"/><circle cx="30" cy="46" r="4" fill="#0a1a2a"/>'),
    "gear": ("#26303a", '<circle cx="50" cy="50" r="22" fill="none" stroke="#c0c8d0" stroke-width="12" stroke-dasharray="9 6"/><circle cx="50" cy="50" r="10" fill="#c0c8d0"/>'),
    "bolt": ("#24204a", '<path d="M56 10 L26 56 H48 L40 90 L76 40 H54 Z" fill="#ffe14a"/>'),
    "chest": ("#2a1e10", '<rect x="18" y="38" width="64" height="42" fill="#9a6a30"/><path d="M18 38 C18 18 82 18 82 38 Z" fill="#b8843c"/><rect x="44" y="44" width="12" height="14" fill="#e8c050"/>'),
    "arrow": ("#2a2418", '<path d="M18 82 L72 28" stroke="#c8a870" stroke-width="7"/><path d="M64 20 L84 16 L80 36 Z" fill="#c0c8d0"/><path d="M18 82 L26 66 M18 82 L34 74" stroke="#e8e0d0" stroke-width="5"/>'),
    "kick": ("#2e1c14", '<path d="M30 20 L48 20 L54 56 L80 64 L78 80 L34 80 Z" fill="#c9965a"/>'),
    "stealth": ("#1a1a24", '<circle cx="50" cy="50" r="30" fill="#4a4a6a"/><path d="M26 50 C38 34 62 34 74 50 C62 66 38 66 26 50 Z" fill="#1a1a24"/><circle cx="50" cy="50" r="8" fill="#9aa0d0"/>'),
}


def icon_svg(kind):
    bg, shape = ICON_ART[kind]
    return (f'<svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" style="display:block">'
            f'<defs><linearGradient id="sh_{kind}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".18"/>'
            f'<stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".35"/></linearGradient></defs>'
            f'<rect width="100" height="100" fill="{bg}"/>{shape}<rect width="100" height="100" fill="url(#sh_{kind})"/></svg>')


def icon_box(x, y, size, kind, border="#000", style=""):
    return box(x, y, size, size, f"border:1px solid {border};overflow:hidden;{style}", icon_svg(kind))


# ---------------------------------------------------------------------------
# Rendering (local headless Chrome)
# ---------------------------------------------------------------------------
def find_chrome():
    cands = [os.environ.get("CHROME"), r"C:\Program Files\Google\Chrome\Application\chrome.exe",
             r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
             shutil.which("chrome"), shutil.which("google-chrome"), shutil.which("chromium")]
    for c in cands:
        if c and Path(c).exists():
            return c
    sys.exit("Chrome not found (set CHROME=<path to chrome>)")


def chrome_args(chrome, tmp):
    return [chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
            f"--user-data-dir={Path(tmp) / 'chrome_profile'}", "--virtual-time-budget=3000"]


def stop(proc):
    """Ends Chrome and its child processes."""
    if proc.poll() is None:
        if os.name == "nt":
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            proc.kill()
    proc.wait()


def screenshot(cmd, out_png, timeout=180):
    """Runs headless Chrome until the screenshot file is written (Chrome may not exit by itself)."""
    if out_png.exists():
        out_png.unlink()
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        start, last = time.time(), -1
        while time.time() - start < timeout:
            if out_png.exists():
                size = out_png.stat().st_size
                if size > 0 and size == last:
                    return
                last = size
            elif proc.poll() is not None:
                raise RuntimeError(f"Chrome ended without writing {out_png}")
            time.sleep(0.5)
        raise TimeoutError(f"no screenshot after {timeout}s: {out_png}")
    finally:
        stop(proc)


def dump_dom(cmd, timeout=180):
    """Runs headless Chrome with --dump-dom until the whole document is printed."""
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    chunks = []

    def pump():
        for chunk in iter(lambda: proc.stdout.read(4096), b""):
            chunks.append(chunk)

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()
    try:
        start = time.time()
        while time.time() - start < timeout:
            data = b"".join(chunks)
            if b"</html>" in data or (proc.poll() is not None and not reader.is_alive()):
                return data.decode("utf-8", "replace")
            time.sleep(0.3)
        raise TimeoutError("no DOM from Chrome after %ds" % timeout)
    finally:
        stop(proc)


def render(chrome, body, call, out_png, tmp):
    doc = (f'<!doctype html><html><head><meta charset="utf-8"><style>{page_css(call)}</style></head>'
           f'<body><div class="sky"></div>{HILLS}{body}{FIT_JS}</body></html>')
    page = Path(tmp) / (out_png.stem + ".html")
    page.write_text(doc, encoding="utf-8")
    # pass 1: let the page measure itself, pass 2: screenshot at that height
    dom = dump_dom(chrome_args(chrome, tmp) + ["--window-size=1600,4000", "--dump-dom", page.as_uri()])
    m = re.search(r'data-h="(\d+)"', dom)
    height = int(m.group(1)) if m else 1200
    screenshot(chrome_args(chrome, tmp) + [f"--window-size={PAGE_W},{height}", f"--screenshot={out_png}", page.as_uri()], out_png)
    return height


def run_pages(root, pages, call):
    """pages: list of (file stem, function returning page body html)."""
    out = root / "docs" / "images"
    out.mkdir(parents=True, exist_ok=True)
    chrome = find_chrome()
    tmp = tempfile.mkdtemp(prefix="ezwow_readme_")
    try:
        for stem, fn in pages:
            png = out / f"{stem}.png"
            h = render(chrome, fn(), call, png, tmp)
            print("wrote", png, h)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ---------------------------------------------------------------------------
# EzWoW - Utility Bar
# ---------------------------------------------------------------------------
TITLE = "EzWoW - Utility Bar"


def load(root):
    init = read(root, "Core/Init.lua")
    loc = read(root, "Core/Locales.lua")
    ow = read(root, "UI/OptionsWindow.lua")
    tb = read(root, "UI/ToolbarFrame.lua")
    style = {k: rgb_list(v) for k, v in re.findall(r"(\w+)\s*=\s*\{\s*([\d.,\s]+)\}", lua_table(init, r"ns\.Style = \{"))}
    th = {"bg": style["bgPrimary"], "bgSub": style["bgSecondary"], "border": style["border"], "text": style["textBody"],
          "muted": style["textMuted"], "accent": style["accent"]}
    dflt = {k: v.strip() for k, v in re.findall(r"^\s*(\w+)\s*=\s*([^,\n]+),", lua_table(init, r"ns\.DEFAULTS = \{"), re.M)}
    order = re.findall(r'"(\w+)"', lua_table(init, r"ns\.DEFAULT_ORDER = \{"))
    groups = lua_table(loc, r"local GROUP_NAMES = \{")
    G = {"ko": lua_strings(lua_table(groups, r"koKR = \{")), "en": lua_strings(lua_table(groups, r"enUS = \{"))}
    # option strings: the table that holds "subtitle" for koKR / enUS
    L = {}
    for lang, code in (("ko", "koKR"), ("en", "enUS")):
        start = [m.start() for m in re.finditer(rf"\b{code} = \{{", loc)]
        for s in start:
            body = lua_table(loc[s:], rf"{code} = \{{")
            if "subtitle" in body:
                L[lang] = lua_strings(body)
    for k, v in L["en"].items():
        L["ko"].setdefault(k, v)
    size = re.search(r"configFrame:SetSize\((\d+), (\d+)\)", ow)
    checks = [(k, -int(y)) for _, _, k, y in re.findall(r'local (\w+), (\w+) = CreateOptionCheck\("(\w+)", (-?\d+)\)', ow)]
    sections = [(k, -int(y)) for _, k, y in re.findall(r'local (\w+) = CreateSectionHeader\(ns:L\("(\w+)"\), (-?\d+)\)', ow)]
    steppers = [(-int(y), int(x)) for _, _, x, y in re.findall(r"local (\w+), (\w+) = CreateStepper\((\d+), (-?\d+)", ow)]
    actions = [(k, int(x), -int(y)) for k, x, y in re.findall(r'CreateActionButton\(ns:L\("(\w+)"\), (\d+), (-?\d+)', ow)]
    ctrl = [(n, int(o)) for n, o in re.findall(r'CreateToolbarControl\("\w+", "(\w+)", (-?\d+)', tb)]
    return {"th": th, "dflt": dflt, "order": order, "G": G, "L": L, "W": int(size.group(1)), "H": int(size.group(2)),
            "checks": checks, "sections": sections, "steppers": steppers, "actions": actions, "ctrl": ctrl,
            "icon": icon_data(find_file(root, "Media/Icon.png"))}


T = {
    "ko": {
        "lead": "가방의 사용 아이템 · 착용 장비 · 전문기술 · 직업 스킬을 분류별로 자동 정리하는 단축바",
        "notes": [
            ("제목 줄", "마우스를 올리면 전체 접기/펼치기 · 잠금/해제 · 설정(톱니) 단추와 조작 안내 툴팁. 잠금 해제 상태에서는 <b>좌클릭 드래그</b>, 잠긴 상태에서는 <b>Ctrl + 드래그</b>로 이동합니다."),
            ("분류 헤더", "클릭해 접기/펼치기(저장됨). 잠금 해제 상태에서 위 · 아래로 끌어 분류 순서를 바꿉니다."),
            ("아이콘 숨기기", "잠금 해제 상태에서 제목에 마우스를 올리면 아이콘 오른쪽 위에 작은 x가 생깁니다. 설정창 “숨긴 아이콘 복원”으로 되돌립니다."),
            ("접힌 분류", "“>” 표시와 개수만 보입니다."),
            ("크기 조절 · 재고 경고", "잠금 해제 상태에서 오른쪽 아래 모서리로 너비 · 높이 조절. 얼마 남지 않은 소모품 · 직업 재료 · 탄약은 숫자가 빨간색."),
        ],
        "more": [
            ("애완동물 자동 소환", "설정에서 켜면(기본 꺼짐) 애완동물이 없을 때 즐겨찾기 중 하나(없으면 아무거나)를 불러냅니다. 전투 · 탈것 · 비행 · 인스턴스 · 은신 · 시전 중에는 하지 않고, 직접 넣은 뒤에는 다시 부를 때까지 쉽니다."),
            ("전투 중", "보안 버튼이라 전투 중에도 클릭해 씁니다. 목록은 그대로 두고 수량만 갱신하며, 다 쓴 아이템은 반투명하게 두었다가 전투가 끝나면 정리합니다."),
            ("키 누를 때 시전", "단축바 단추는 게임의 “키를 누를 때 시전” 설정을 그대로 따릅니다."),
        ],
        "moreTitle": "그 밖의 기능",
        "foot": "애드온 코드의 창 크기 · 좌표 · 색상 · 문구로 재현한 예시 화면입니다. 아이콘과 아이템은 예시이며 실제 게임 화면과 조금 다를 수 있습니다.",
        "sLead": "/ezub · 표시할 분류, 아이콘 배치, 단축바 크기 · 상태",
        "sTitle": "설정창",
        "sNotes": [
            ("표시할 분류", "15개 분류를 하나씩 켜고 끕니다."),
            ("아이콘 배치", "분류 없이 합쳐 보기, 음식 · 물약 · 붕대 최고 등급만, 위로 펼치기, 재고 부족 빨간색 경고, 애완동물 자동 소환(기본 꺼짐), 언어(목록에서 선택), 스킬 단계(최고 / 모든 단계)."),
            ("크기 · 상태", "아이콘 크기 24~64, 한 줄 개수 4~16, 불투명도 30~100%, 마우스 올릴 때만 표시."),
            ("단추", "잠금 · 숨김, 전체 펼치기 · 접기, 새로고침, 숨긴 아이콘 복원(개수)."),
            ("위치 초기화 · 후원", "단축바를 화면 가운데 아래로 되돌립니다."),
        ],
        "sFoot": "애드온 코드의 창 크기 · 좌표 · 색상 · 문구로 재현한 예시 화면입니다. 체크 상태와 숫자는 기본값입니다(애완동물 자동 소환은 애완동물 도감 기능이 있는 클라이언트에서만 보입니다).",
    },
    "en": {
        "lead": "One compact bar that sorts usable bag items, equipped gear, professions and class skills by category",
        "notes": [
            ("Title bar", "Hover for collapse/expand all, lock/unlock, settings (gear) and a controls tooltip. <b>Left-drag</b> moves the bar while unlocked, <b>Ctrl + drag</b> while locked."),
            ("Category header", "Click to collapse or expand (saved). While unlocked, drag up or down to reorder categories."),
            ("Hide an icon", "While unlocked, hover the title and a small x appears on each icon. Bring icons back with “Restore hidden icons”."),
            ("Collapsed category", "Only “>” and the count are shown."),
            ("Resize · low stock", "While unlocked, drag the bottom-right corner to resize. Consumables, reagents and ammo that are running low show a red count."),
        ],
        "more": [
            ("Companion pet", "Turn it on in the settings (off by default) and a favourite pet (any pet if you have no favourites) is summoned when none is out. Never in combat, mounted, flying, in instances, stealthed or while casting; after you put a pet away it waits until you summon one yourself."),
            ("In combat", "Secure buttons keep working in combat. The layout stays put and only counts update; used-up items are dimmed and removed after combat."),
            ("Cast on key down", "The bar's buttons follow the game's “cast on key down” option."),
        ],
        "moreTitle": "Also",
        "foot": "Mock-ups rebuilt from the window sizes, coordinates, colours and strings in the addon code. Icons and items are examples; the in-game look may differ slightly.",
        "sLead": "/ezub · visible categories, icon layout, bar size & state",
        "sTitle": "Settings",
        "sNotes": [
            ("Visible categories", "Turn each of the 15 categories on or off."),
            ("Icon layout", "All icons without categories, best food/potions/bandages only, grow upward, low-stock warning, auto-summon companion pet (off by default), language (pick from the list), spell ranks (highest / all)."),
            ("Size · state", "Icon size 24–64, icons per row 4–16, opacity 30–100%, show only on mouseover."),
            ("Buttons", "Lock and hide, expand and collapse all, refresh, restore hidden icons (count)."),
            ("Reset position · support", "Put the bar back near the lower centre of the screen."),
        ],
        "sFoot": "Mock-up rebuilt from the window size, coordinates, colours and strings in the addon code. Check boxes and numbers show the defaults (the companion pet option only shows on clients with the pet journal).",
    },
}

# example contents: (category, [(icon, count, low)], collapsed)
BAR = [
    ("potion", [("potion", "12", False), ("mana", "8", False), ("stone", "1", True)], False),
    ("trinket", [("ring", "", False), ("helm", "", False)], False),
    ("food", [("food", "20", False), ("drink", "18", False), ("food", "6", False)], False),
    ("bandage", [("bandage", "14", False)], False),
    ("engineering", [("bolt", "", False), ("gear", "", False), ("bolt", "", False)], True),
    ("profession", [("hammer", "", False), ("fire", "", False), ("heal", "", False), ("fish", "", False)], False),
    ("classskill", [("holy", "", False), ("fire", "", False), ("arcane", "", False)], False),
]


def toolbar(ctx, lang):
    th, G, d = ctx["th"], ctx["G"][lang], ctx["dflt"]
    acc = css(th["accent"])
    size, cols = int(d["size"]), int(d["columns"])
    W = max(190, 16 + cols * (size + 4))
    p = [text(12, 8 + 6, TITLE, 10, acc),
         box(5, 3, 128, 23, f"border:1px solid {css(th['accent'], .9)}")]
    for name, off in ctx["ctrl"]:
        g = {"fold": "v", "unlock": "&#9711;", "gear": "&#9881;"}[name]
        p.append(box(W + off - 23, 3, 23, 23, f"background:{css(th['bgSub'], .92)};border:1px solid {css(th['border'], .95)};display:flex;align-items:center;justify-content:center",
                     f'<span style="color:{css(th["text"])};font-size:{px(12)}">{g}</span>'))
    y = 32
    rows = {}
    for cat, items, collapsed in BAR:
        p.append(box(8, y, W - 16, 20, f"background:{css(th['bgSub'], .92)}"))
        p.append(box(8, y, 2, 20, f"background:{css(th['accent'], .95)}"))
        p.append(text(20, y + 10, esc(f'{">" if collapsed else "v"}  {G[cat]}  |  {len(items)}'), 10, css(th["text"])))
        p.append(text(W - 16, y + 10, "↕", 10, css(th["accent"], .85), anchor="right"))
        rows[cat] = y
        y += 25
        if collapsed:
            continue
        for n, (ic, cnt, low) in enumerate(items):
            x = 8 + (n % cols) * (size + 4)
            yy = y + (n // cols) * (size + 4)
            inner = f'<div class="abs" style="inset:{px(2)}">{icon_svg(ic)}</div>'
            if cnt:
                inner += (f'<div class="t" style="right:{px(3)};bottom:{px(2)};font-size:{px(12)};font-weight:700;'
                          f'color:{"#ff5252" if low else "#fff"};{OUTLINE}">{cnt}</div>')
            p.append(box(x, yy, size, size, "background:#000;border:1px solid #000;overflow:visible", inner))
            if cat == "potion" and n == 0:   # hide-icon x on the first icon
                p.append(box(x + size - 12, yy - 2, 14, 14, "background:rgba(26,15,13,.92);outline:1px solid rgba(184,77,61,.95);display:flex;align-items:center;justify-content:center",
                             f'<span style="color:#fff;font-size:{px(9)};line-height:1">x</span>'))
        y += -(-len(items) // cols) * (size + 4) + 5
    H = max(48, y + 10)
    p.append(f'<div class="abs" style="right:{px(3)};bottom:{px(3)};width:{px(14)};height:{px(14)};'
             f'background:linear-gradient(135deg,transparent 50%,#7c8a96 50%,#7c8a96 58%,transparent 58%,transparent 70%,#7c8a96 70%,#7c8a96 78%,transparent 78%)"></div>')
    return W, H, "".join(p), rows


def ui_page(lang, ctx):
    global S
    S = 1.4
    t, th = T[lang], ctx["th"]
    W, H, inner, rows = toolbar(ctx, lang)
    bx, by = 50, 168
    parts = [heading(TITLE, esc(t["lead"])),
             f'<div class="abs" style="left:{bx}px;top:{by}px;width:{px(W)};height:{px(H)};background:{css(th["bg"], .93)};'
             f'border:1px solid {css(th["border"], .9)}">{inner}</div>']
    calls = [(bx + W * S + 4, by + 15 * S), (bx - 16, by + (rows["potion"] + 10) * S), (bx - 16, by + (rows["potion"] + 45) * S),
             (bx + W * S + 4, by + (rows["engineering"] + 10) * S), (bx + W * S + 4, by + H * S - 6)]
    parts.append(callouts(calls))
    nx = bx + W * S + 60
    parts.append(notes_block(nx, by, PAGE_W - nx - 40, t["notes"]))
    more = "".join(f'<div class="note" style="margin-left:40px"><div><b>{esc(a)}</b> — {esc(b_)}</div></div>' for a, b_ in t["more"])
    parts.append(f'<div class="notes" style="left:{nx:.0f}px;top:{by + 265}px;width:{PAGE_W - nx - 40:.0f}px">'
                 f'<div style="font-size:18px;font-weight:700;color:{css(th["accent"])};margin:0 0 10px 40px">{esc(t["moreTitle"])}</div>{more}</div>')
    parts.append(f'<div class="foot" style="left:50px;width:1500px">{esc(t["foot"])}</div>')
    return "".join(parts)


def settings_page(lang, ctx):
    global S
    S = 1.15
    t, L, G, th, d = T[lang], ctx["L"][lang], ctx["G"][lang], ctx["th"], ctx["dflt"]
    acc = css(th["accent"])
    W, H = ctx["W"], ctx["H"]
    win = Window(th, W, H, TITLE, esc(L["subtitle"]), ctx["icon"], header=58, close=22, close_off=10)
    for key, y in ctx["sections"]:
        win.section(20, y, esc(L[key]), line_dy=20)
    for i, cat in enumerate(ctx["order"]):
        win.check(20 + (i % 2) * 195, 90 + (i // 2) * 25, esc(G[cat]), True, label_w=150)
    for key, y in ctx["checks"]:
        win.check(20, y, esc(L[key]), d.get(key) == "true", size=25, label_w=340)
    win.button(20, 432, 187, 28, esc(f'{L["language"]}: Auto ▼'))
    win.button(213, 432, 187, 28, esc(f'{L["spellRanks"]}: {L["highestRank"]} ▼'))
    vals = [(L["size"], d["size"]), (L["columns"], d["columns"]), (L["opacity"], f'{round(float(d["opacity"]) * 100)}%')]
    for (y, x), (lab, v) in zip(ctx["steppers"], vals):
        win.stepper(x, y, esc(lab), esc(v), 94, 160, bw=27, bh=29, label_dy=8, label_w=88)
    win.check(210, 528, esc(L["fade"]), d.get("fade") == "true", size=26, label_w=160)
    label = {"lock": L["lock"], "show": L["hide"], "expand": L["expand"], "collapse": L["collapse"], "refresh": L["refresh"],
             "restore": f'{L["restore"]} (1)'}
    for key, x, y in ctx["actions"]:
        if key == "resetPos":
            continue
        win.button(x, y, 181, 31, esc(label[key]), color="#f0cc87" if key == "restore" else None)
    win.add(f'<div class="t" style="left:{px(20)};top:{px(670)};font-size:{px(10)};color:#808080;{SHADOW}">{esc(L["hint"])}</div>')
    win.button(20, H - 36 - 33, 185, 33, esc(L["resetPos"]))
    win.button(W - 20 - 185, H - 36 - 33, 185, 33, esc(L["donate"]), accent=True, bg="rgba(46,36,61,.96)")
    win.add(f'<div class="t" style="left:50%;transform:translateX(-50%);bottom:{px(12)};font-size:{px(10)};color:#808080;{SHADOW}">'
            f'EzWoW - Utility Bar {esc(ctx.get("version", ""))}  ·  /ezub</div>')
    ox, oy = 60, 150
    secs = dict(ctx["sections"])
    spans = [(secs["categories"], secs["layout"] - 6), (secs["layout"], 462), (secs["controls"], 556), (560, 662), (H - 70, H - 36)]
    calls = [(ox + W * S + 22, oy + (a + b_) / 2 * S) for a, b_ in spans]
    nx = ox + W * S + 70
    return (heading(TITLE, esc(t["sLead"]), t["sTitle"]) + win.html(ox, oy) + callouts(calls)
            + notes_block(nx, oy + 6, PAGE_W - nx - 40, [(a, esc(b_)) for a, b_ in t["sNotes"]])
            + f'<div class="foot" style="left:50px;width:1500px">{esc(t["sFoot"])}</div>')


def main(root: Path):
    ctx = load(root)
    ctx["version"] = toc_version(root)
    call = hexc(ctx["th"]["accent"])
    run_pages(root, [(f"{n}_{lang}", (lambda n=n, lang=lang: (ui_page if n == "ui" else settings_page)(lang, ctx)))
                     for lang in ("ko", "en") for n in ("ui", "settings")], call)


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve())
