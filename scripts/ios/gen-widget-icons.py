#!/usr/bin/env python3
"""Lucide cizgi ikonlarini (24x24, design/widget-previews/_gen/*.js icindeki SVG verisi) WidgetKit icin duz
sayi dizilerine cevirir: mobile/ios/BUWidgets/BuIconData.swift uretir. Yay (A) komutlari kubik Bezier'e, daire/dikdortgen
yola cevrilir; boylece Swift tarafinda SVG ayristirici GEREKMEZ.
Kullanim: python -I -X utf8 scripts/ios/gen-widget-icons.py [--preview out.png]
Operasyon kodlari (Double dizisi): 0=moveTo x y | 1=lineTo x y | 2=curveTo x1 y1 x2 y2 x y | 3=close
"""
import math
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'mobile', 'ios', 'BUWidgets', 'BuIconData.swift')

# ad -> SVG govde parcasi (yalniz path/circle/rect)
ICONS = {
    'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    'moon': '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    'flame': '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.4-.5-2-1-3-1.1-2.1-.2-4 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.2.4-2.4 1-3 0 1.4 1 2.5 2.5 2.5Z"/>',
    'utensils': '<path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2M7 2v20M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"/>',
    'map-pin': '<path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
    'clock': '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    'calendar': '<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
    'vote': '<path d="m9 12 2 2 4-4"/><path d="M5 7c0-1.1.9-2 2-2h10a2 2 0 0 1 2 2v12H5V7Z"/><path d="M22 19H2"/>',
    'calendar-clock': '<path d="M21 7.5V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h3.5M16 2v4M8 2v4M3 10h5"/><circle cx="16" cy="16" r="6"/><path d="M16 14v2l1 1"/>',
    'ticket': '<path d="M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z"/><path d="M13 5v2M13 17v2M13 11v2"/>',
    'users': '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>',
    'message-circle': '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
    'qr-code': '<rect x="3" y="3" width="5" height="5" rx="1"/><rect x="16" y="3" width="5" height="5" rx="1"/><rect x="3" y="16" width="5" height="5" rx="1"/><path d="M21 16h-3a2 2 0 0 0-2 2v3M21 21v.01M12 7v3a2 2 0 0 1-2 2H7M3 12h.01M12 3h.01M12 16v.01M16 12h1M21 12v.01M12 21v-1"/>',
    'newspaper': '<path d="M4 22h16a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2v16a2 2 0 0 1-2 2Zm0 0a2 2 0 0 1-2-2v-9c0-1.1.9-2 2-2h2"/><path d="M18 14h-8M15 18h-5M10 6h8v4h-8V6Z"/>',
    'search': '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    'bell': '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    'heart': '<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7Z"/>',
    'circle-check': '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    'lock': '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    'chevron-right': '<path d="m9 18 6-6-6-6"/>',
    'message-square': '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2Z"/>',
    'megaphone': '<path d="m3 11 18-5v12L3 14v-3z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/>',
}

NUM = re.compile(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')


def arc_to_cubics(x1, y1, rx, ry, phi_deg, fa, fs, x2, y2):
    """SVG yayi (W3C F.6.5) -> kubik Bezier listesi [(c1x,c1y,c2x,c2y,x,y)]."""
    if rx == 0 or ry == 0 or (x1 == x2 and y1 == y2):
        return [(x1, y1, x2, y2, x2, y2)]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(phi_deg)
    cp, sp = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cp * dx + sp * dy
    y1p = -sp * dx + cp * dy
    lam = (x1p ** 2) / (rx ** 2) + (y1p ** 2) / (ry ** 2)
    if lam > 1:
        s = math.sqrt(lam)
        rx, ry = rx * s, ry * s
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    co = math.sqrt(max(0.0, num / den)) if den else 0.0
    if fa == fs:
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2

    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    th1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dth = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not fs and dth > 0:
        dth -= 2 * math.pi
    elif fs and dth < 0:
        dth += 2 * math.pi
    n = max(1, int(math.ceil(abs(dth) / (math.pi / 2) - 1e-9)))
    d = dth / n
    t = 4 / 3 * math.tan(d / 4)
    out = []
    a = th1
    for _ in range(n):
        ca, sa = math.cos(a), math.sin(a)
        cb, sb = math.cos(a + d), math.sin(a + d)
        p1 = (ca - t * sa, sa + t * ca)
        p2 = (cb + t * sb, sb - t * cb)
        p3 = (cb, sb)

        def tr(p):
            px, py = p[0] * rx, p[1] * ry
            return (cp * px - sp * py + cx, sp * px + cp * py + cy)

        q1, q2, q3 = tr(p1), tr(p2), tr(p3)
        out.append((q1[0], q1[1], q2[0], q2[1], q3[0], q3[1]))
        a += d
    return out


def parse_path(d):
    toks = re.findall(r'[MmLlHhVvCcSsAaZzQqTt]|' + NUM.pattern, d)
    ops = []
    i = 0
    cmd = None
    x = y = sx = sy = 0.0
    lcx = lcy = None  # son kontrol noktasi (S icin)

    def num():
        nonlocal i
        v = float(toks[i])
        i += 1
        return v

    def flag():
        # yay bayragi: 0/1; bazi yollarda bitisik yazilir ("a3 3 0 011 2"); burada hepsi bosluklu, yine de guvenli oku
        nonlocal i
        t = toks[i]
        if t in ('0', '1'):
            i += 1
            return int(t)
        # bitisik bayrak: "01" gibi
        v = int(t[0])
        toks[i] = t[1:]
        return v

    while i < len(toks):
        t = toks[i]
        if re.match(r'[A-Za-z]', t):
            cmd = t
            i += 1
            if cmd in 'Zz':
                ops.append((3,))
                x, y = sx, sy
                lcx = lcy = None
                continue
        c = cmd
        rel = c.islower()
        C = c.upper()
        if C == 'M':
            nx, ny = num(), num()
            if rel:
                nx += x
                ny += y
            x, y = nx, ny
            sx, sy = x, y
            ops.append((0, x, y))
            cmd = 'l' if rel else 'L'
            lcx = lcy = None
        elif C == 'L':
            nx, ny = num(), num()
            if rel:
                nx += x
                ny += y
            x, y = nx, ny
            ops.append((1, x, y))
            lcx = lcy = None
        elif C == 'H':
            nx = num()
            x = x + nx if rel else nx
            ops.append((1, x, y))
            lcx = lcy = None
        elif C == 'V':
            ny = num()
            y = y + ny if rel else ny
            ops.append((1, x, y))
            lcx = lcy = None
        elif C == 'C':
            a = [num() for _ in range(6)]
            if rel:
                a = [a[0] + x, a[1] + y, a[2] + x, a[3] + y, a[4] + x, a[5] + y]
            ops.append((2,) + tuple(a))
            lcx, lcy = a[2], a[3]
            x, y = a[4], a[5]
        elif C == 'S':
            a = [num() for _ in range(4)]
            if rel:
                a = [a[0] + x, a[1] + y, a[2] + x, a[3] + y]
            c1x = 2 * x - lcx if lcx is not None else x
            c1y = 2 * y - lcy if lcy is not None else y
            ops.append((2, c1x, c1y, a[0], a[1], a[2], a[3]))
            lcx, lcy = a[0], a[1]
            x, y = a[2], a[3]
        elif C == 'A':
            rx, ry, rot = num(), num(), num()
            fa = flag()
            fs = flag()
            nx, ny = num(), num()
            if rel:
                nx += x
                ny += y
            for cu in arc_to_cubics(x, y, rx, ry, rot, fa, fs, nx, ny):
                ops.append((2,) + cu)
            x, y = nx, ny
            lcx = lcy = None
        else:
            raise ValueError('desteklenmeyen komut ' + c)
    return ops


def circle_ops(cx, cy, r):
    k = 0.5522847498 * r
    return [(0, cx + r, cy),
            (2, cx + r, cy + k, cx + k, cy + r, cx, cy + r),
            (2, cx - k, cy + r, cx - r, cy + k, cx - r, cy),
            (2, cx - r, cy - k, cx - k, cy - r, cx, cy - r),
            (2, cx + k, cy - r, cx + r, cy - k, cx + r, cy),
            (3,)]


def rect_ops(x, y, w, h, rx):
    if rx <= 0:
        return [(0, x, y), (1, x + w, y), (1, x + w, y + h), (1, x, y + h), (3,)]
    k = 0.5522847498 * rx
    return [(0, x + rx, y), (1, x + w - rx, y),
            (2, x + w - rx + k, y, x + w, y + rx - k, x + w, y + rx),
            (1, x + w, y + h - rx),
            (2, x + w, y + h - rx + k, x + w - rx + k, y + h, x + w - rx, y + h),
            (1, x + rx, y + h),
            (2, x + rx - k, y + h, x, y + h - rx + k, x, y + h - rx),
            (1, x, y + rx),
            (2, x, y + rx - k, x + rx - k, y, x + rx, y),
            (3,)]


def icon_ops(body):
    ops = []
    for m in re.finditer(r'<(path|circle|rect)\s+([^/]*)/>', body):
        kind, attrs = m.group(1), dict(re.findall(r'(\w+)="([^"]*)"', m.group(2)))
        if kind == 'path':
            ops += parse_path(attrs['d'])
        elif kind == 'circle':
            ops += circle_ops(float(attrs['cx']), float(attrs['cy']), float(attrs['r']))
        else:
            ops += rect_ops(float(attrs['x']), float(attrs['y']), float(attrs['width']),
                            float(attrs['height']), float(attrs.get('rx', 0)))
    return ops


def fmt(v):
    s = ('%.4f' % v).rstrip('0').rstrip('.')
    if s in ('', '-0'):
        s = '0'
    return s if ('.' in s) else s + '.0'


def flat(ops):
    out = []
    for op in ops:
        out.append(str(float(op[0])) if False else fmt(op[0]))
        out += [fmt(v) for v in op[1:]]
    return out


def to_swift():
    lines = []
    lines.append('// BuIconData.swift  --  URETILMISTIR: scripts/ios/gen-widget-icons.py (elle DUZENLEMEYIN).')
    lines.append('// Lucide cizgi ikonlari, 24x24 uzayinda. Operasyon: 0 moveTo(x y), 1 lineTo(x y), 2 curveTo(x1 y1 x2 y2 x y), 3 close.')
    lines.append('')
    lines.append('enum BuIconData {')
    for name in sorted(ICONS):
        vals = flat(icon_ops(ICONS[name]))
        ident = 'i_' + name.replace('-', '_')
        lines.append('    static let %s: [Double] = [' % ident)
        row = []
        for v in vals:
            row.append(v)
            if len(row) == 14:
                lines.append('        ' + ', '.join(row) + ',')
                row = []
        if row:
            lines.append('        ' + ', '.join(row) + ',')
        lines.append('    ]')
    lines.append('')
    lines.append('    static func ops(for name: String) -> [Double] {')
    lines.append('        switch name {')
    for name in sorted(ICONS):
        lines.append('        case "%s": return i_%s' % (name, name.replace('-', '_')))
    lines.append('        default: return []')
    lines.append('        }')
    lines.append('    }')
    lines.append('}')
    return '\n'.join(lines) + '\n'


def preview(path):
    from PIL import Image, ImageDraw
    names = sorted(ICONS)
    S = 96
    cols = 8
    rows = (len(names) + cols - 1) // cols
    im = Image.new('RGB', (cols * (S + 10) + 10, rows * (S + 10) + 10), 'white')
    dr = ImageDraw.Draw(im)
    k = S / 24.0
    for idx, n in enumerate(names):
        ox = 10 + (idx % cols) * (S + 10)
        oy = 10 + (idx // cols) * (S + 10)
        pts = []
        cur = None

        def flush():
            if len(pts) > 1:
                dr.line(pts, fill='black', width=max(1, int(1.5 * k)), joint='curve')

        for op in icon_ops(ICONS[n]):
            if op[0] == 0:
                flush()
                pts = [(ox + op[1] * k, oy + op[2] * k)]
                start = pts[0]
                cur = (op[1], op[2])
            elif op[0] == 1:
                pts.append((ox + op[1] * k, oy + op[2] * k))
                cur = (op[1], op[2])
            elif op[0] == 2:
                x0, y0 = cur
                for s in range(1, 17):
                    t = s / 16
                    u = 1 - t
                    bx = u ** 3 * x0 + 3 * u * u * t * op[1] + 3 * u * t * t * op[3] + t ** 3 * op[5]
                    by = u ** 3 * y0 + 3 * u * u * t * op[2] + 3 * u * t * t * op[4] + t ** 3 * op[6]
                    pts.append((ox + bx * k, oy + by * k))
                cur = (op[5], op[6])
            else:
                pts.append(start)
        flush()
    im.save(path)


if __name__ == '__main__':
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    else:
        with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
            f.write(to_swift())
        print('yazildi:', OUT)
