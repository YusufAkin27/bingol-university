#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Android ana ekran widget'lari: RemoteViews yerlesimleri (res/layout/bw_*.xml) ve sabit cizimler (res/drawable/bw_*.xml).

Calistirma: python -I -X utf8 mobile/tool/gen_android_widgets_layouts.py
Olculer design/widget-previews/DESIGN_SYSTEM.md tablolarindan (dp; yazi dp = sabit, sistem yazi olcegi uygulanmaz).
Renkler @color/bu_widget_* (values / values-night): tema degisince launcher yeniden cizer, kodla renk verilmez.
"""
import os

RES = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')

# --- tipografi: (boyut, satir, harf araligi em) ---
CAPTION = (10, 12, 0.08)
MICRO = (11, 14, 0)
SMALL = (12, 16, 0)
BODY = (13, 18, 0)
BODYL = (14, 18, 0)
QUESTION = (15, 20, -0.01)
TITLE = (17, 22, -0.01)
DISPLAY = (22, 26, -0.02)
NUMBER = (34, 38, -0.03)
NUMROW = (28, 32, -0.03)
HERO = (34, 36, -0.03)
BDAY_S = (13, 13, 0)
BMON_S = (9, 10, 0.08)
BDAY_L = (18, 20, 0)
BMON_L = (10, 12, 0.08)

NS = 'xmlns:android="http://schemas.android.com/apk/res/android"'


def dim(v):
    if v in ('wrap', 'wrap_content'):
        return 'wrap_content'
    if v in ('match', 'match_parent'):
        return 'match_parent'
    return '%sdp' % v


class N:
    def __init__(self, tag, a=None, kids=None, w='wrap', h='wrap', flex=0, mt=0, mb=0, ms=0, me=0, grav=None):
        self.tag, self.a, self.kids = tag, dict(a or {}), kids or []
        self.w, self.h, self.flex = w, h, flex
        self.mt, self.mb, self.ms, self.me, self.grav = mt, mb, ms, me, grav

    def render(self, parent=None, ind=0, root=False):
        pad = '    ' * ind
        a = dict(self.a)
        w, h = dim(self.w), dim(self.h)
        if self.flex:
            if parent == 'horizontal':
                w = '0dp'
            elif parent == 'vertical':
                h = '0dp'
            a['android:layout_weight'] = str(self.flex)
        out = [pad + '<' + self.tag]
        if root:
            out.append(pad + '    ' + NS)
        out.append(pad + '    android:layout_width="%s"' % w)
        out.append(pad + '    android:layout_height="%s"' % h)
        for k, v, key in (('mt', self.mt, 'layout_marginTop'), ('mb', self.mb, 'layout_marginBottom'),
                          ('ms', self.ms, 'layout_marginStart'), ('me', self.me, 'layout_marginEnd')):
            if v:
                out.append(pad + '    android:%s="%sdp"' % (key, v))
        if self.grav:
            out.append(pad + '    android:layout_gravity="%s"' % self.grav)
        for k, v in a.items():
            out.append(pad + '    %s="%s"' % (k if (':' in k or k == 'style') else 'android:' + k, v))
        orient = a.get('android:orientation') or a.get('orientation')
        if self.kids:
            out[-1] += '>'
            for c in self.kids:
                out.append(c.render(orient, ind + 1))
            out.append(pad + '</%s>' % self.tag)
        else:
            out[-1] += ' />'
        return '\n'.join(out)


def ident(i):
    return '@+id/' + i if i else None


def V(kids, id=None, bg=None, pad=None, gravity=None, vis=None, **lp):
    a = {'orientation': 'vertical'}
    _common(a, id, bg, pad, gravity, vis)
    return N('LinearLayout', a, kids, **lp)


def H(kids, id=None, bg=None, pad=None, gravity=None, vis=None, **lp):
    a = {'orientation': 'horizontal'}
    _common(a, id, bg, pad, gravity, vis)
    return N('LinearLayout', a, kids, **lp)


def F(kids=None, id=None, bg=None, pad=None, gravity=None, vis=None, **lp):
    a = {}
    _common(a, id, bg, pad, gravity, vis)
    return N('FrameLayout', a, kids or [], **lp)


def _common(a, id, bg, pad, gravity, vis=None):
    if vis:
        a['visibility'] = vis
    if id:
        a['id'] = ident(id)
    if bg:
        a['background'] = bg if bg.startswith('@') else '@color/bu_widget_' + bg
    if pad is not None:
        if isinstance(pad, tuple):
            a['paddingTop'], a['paddingEnd'], a['paddingBottom'], a['paddingStart'] = ['%sdp' % x for x in pad]
        else:
            a['padding'] = '%sdp' % pad
    if gravity:
        a['gravity'] = gravity


def tv(id, role, color='text1', lines=1, w='wrap', gravity=None, vis=None, **lp):
    size, line, tr = role
    a = {'textSize': '%sdp' % size, 'lineHeight': '%sdp' % line, 'includeFontPadding': 'false',
         'maxLines': str(lines), 'ellipsize': 'end', 'textColor': '@color/bu_widget_' + color,
         'textAlignment': 'viewStart', 'textDirection': 'locale'}
    if id:
        a['id'] = ident(id)
    if tr:
        a['letterSpacing'] = str(tr)
    if tr == 0.08:
        a['textAllCaps'] = 'true'
    if gravity:
        a['gravity'] = gravity
        if gravity in ('center', 'center_horizontal'):
            a['textAlignment'] = 'center'
    if vis:
        a['visibility'] = vis
    if lines > 1:
        a['maxLines'] = str(lines)
    if 'bg' in lp:
        a['background'] = lp.pop('bg')
    if 'pad' in lp:
        p = lp.pop('pad')
        a['paddingTop'], a['paddingEnd'], a['paddingBottom'], a['paddingStart'] = ['%sdp' % x for x in p]
    return N('TextView', a, w=w, **lp)


def ic(id, name, size, color='text2', vis=None, **lp):
    a = {'src': '@drawable/ic_w_%s' % name.replace('-', '_') if name else '@drawable/ic_w_search',
         'tint': '@color/bu_widget_' + color, 'scaleType': 'fitCenter', 'importantForAccessibility': 'no'}
    if id:
        a['id'] = ident(id)
    if vis:
        a['visibility'] = vis
    return N('ImageView', a, w=size, h=size, **lp)


def logo(id, h=12, **lp):
    a = {'src': '@drawable/bw_logo', 'adjustViewBounds': 'true', 'scaleType': 'fitCenter', 'alpha': '0.9',
         'importantForAccessibility': 'no'}
    if id:
        a['id'] = ident(id)
    return N('ImageView', a, w='wrap', h=h, **lp)


def div(vertical=False, id=None, **lp):
    a = {'background': '@color/bu_widget_border'}
    if id:
        a['id'] = ident(id)
    if vertical:
        return N('FrameLayout', a, w=1, h='match', **lp)
    return N('FrameLayout', a, w='match', h=1, **lp)


def vspacer(**lp):
    return N('FrameLayout', {}, flex=1, w='match', h=0, **lp)


def hspacer(**lp):
    return N('FrameLayout', {}, flex=1, w=0, h='match', **lp)


def root(kids, pad=16, id='bw_root'):
    return V(kids, id=id, bg='@drawable/bw_bg', pad=pad, w='match', h='match',
             **{})


def header(p, icon, cap=CAPTION, cap_color='text3', icon_color='text3', icon_size=12, logo_h=12, gap=12, with_logo=True,
          cap_lines=1):
    kids = []
    if icon:
        kids.append(ic(p + '_hicon', icon, icon_size, icon_color))
    kids.append(tv(p + '_hcap', cap, cap_color, lines=cap_lines, flex=1, w='wrap', ms=4 if icon else 0,
                   gravity='center_vertical', h=16))
    if with_logo:
        kids.append(logo(p + '_logo', logo_h, ms=6))
    return H(kids, gravity='center_vertical', w='match', h=16, mb=gap)


def write(path, text):
    full = os.path.join(RES, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text if text.endswith('\n') else text + '\n')


def layout(name, node):
    write('layout/%s.xml' % name, '<?xml version="1.0" encoding="utf-8"?>\n<!-- Uretilmis: mobile/tool/gen_android_widgets_layouts.py -->\n' + node.render(root=True))


# ====================================================================== drawables
def shape(name, color, radius=0, stroke=None, oval=False, w=None, h=None, comment=''):
    s = ['<?xml version="1.0" encoding="utf-8"?>', '<!-- Uretilmis: mobile/tool/gen_android_widgets_layouts.py -->',
         '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="%s">' % ('oval' if oval else 'rectangle')]
    if color:
        s.append('    <solid android:color="%s" />' % color)
    if radius:
        s.append('    <corners android:radius="%sdp" />' % radius)
    if stroke:
        s.append('    <stroke android:width="1dp" android:color="%s" />' % stroke)
    if w:
        s.append('    <size android:width="%sdp" android:height="%sdp" />' % (w, h))
    s.append('</shape>')
    write('drawable/%s.xml' % name, '\n'.join(s))


def drawables():
    C = '@color/bu_widget_'
    shape('bw_bg', C + 'bg', 28, C + 'border')
    shape('bw_chip12', C + 'chip', 12)
    shape('bw_chip14', C + 'chip', 14)
    shape('bw_badge_inverse8', C + 'inverse_bg', 8)
    shape('bw_badge8', C + 'badge_fill', 8, C + 'badge_border')
    shape('bw_badge10', C + 'badge_fill', 10, C + 'badge_border')
    shape('bw_pill', C + 'inverse_bg', 14)
    shape('bw_dot', C + 'text1', 0, oval=True)
    shape('bw_dot_passive', C + 'dot_passive', 0, oval=True)
    shape('bw_dot_danger', C + 'danger', 0, oval=True)
    for name, fill in (('bw_bar_a', 'bar_fill'), ('bw_bar_b', 'bar_fill_dim')):
        write('drawable/%s.xml' % name, '''<?xml version="1.0" encoding="utf-8"?>
<!-- Uretilmis: mobile/tool/gen_android_widgets_layouts.py. Anket cubugu: iz + dolgu (yaricap 2). -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background">
        <shape android:shape="rectangle">
            <solid android:color="@color/bu_widget_bar_track" />
            <corners android:radius="2dp" />
        </shape>
    </item>
    <item android:id="@android:id/progress">
        <clip>
            <shape android:shape="rectangle">
                <solid android:color="@color/%s" />
                <corners android:radius="2dp" />
            </shape>
        </clip>
    </item>
</layer-list>''' % ('bu_widget_' + fill))
    write('values/widget_extra_colors.xml', '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Lider olmayan anket cubugu: barFill %45 opaklik (DESIGN_SYSTEM bolum 3). -->
    <color name="bu_widget_bar_fill_dim">#7309090B</color>
</resources>''')
    write('values-night/widget_extra_colors.xml', '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="bu_widget_bar_fill_dim">#73FAFAFA</color>
</resources>''')


def bar(id, dim_=False):
    a = {'id': ident(id), 'style': '?android:attr/progressBarStyleHorizontal', 'max': '100', 'progress': '0',
         'indeterminate': 'false', 'progressDrawable': '@drawable/bw_bar_%s' % ('b' if dim_ else 'a'),
         'minHeight': '4dp', 'maxHeight': '4dp', 'visibility': 'gone'}
    return N('ProgressBar', a, w='match', h=4, mt=4)


# ====================================================================== ortak
def sized(prefix, small, medium, large):
    layout('bw_%s_small' % prefix, small)
    layout('bw_%s_medium' % prefix, medium)
    layout('bw_%s_large' % prefix, large)


def gen_common():
    layout('bw_loading', root([]))
    layout('bw_signedout', root([
        vspacer(),
        tv('so_title', DISPLAY, 'text1', lines=2, w='match'),
        tv('so_sub', MICRO, 'text2', lines=2, w='match', mt=4),
        vspacer(),
    ], id='bw_root'))
    # bos durum: kind display (baslik DISPLAY) / text (ortali, kucuk baslik)
    for size, isz, sub_role, sub_c in (('small', 20, SMALL, 'text3'), ('medium', 22, BODY, 'text2'), ('large', 28, BODY, 'text2')):
        layout('bw_empty_display_%s' % size, root([
            header('e', 'sun', CAPTION, 'text3', 'text3'),
            V([
                ic('e_icon', 'circle-check', isz, 'text2', vis='gone', mb=6),
                tv('e_title', DISPLAY, 'text1', lines=2, w='match'),
                tv('e_sub', sub_role, sub_c, lines=2, w='match', mt=4),
            ], gravity='center_vertical', w='match', flex=1),
        ]))
    for size, isz, t_role, s_role in (('small', 20, BODY, None), ('medium', 22, BODY, MICRO), ('large', 28, QUESTION, SMALL)):
        kids = [ic('e_icon', 'calendar', isz, 'text3', mb=8),
                tv('e_title', t_role, 'text2', lines=2, w='match', gravity='center_horizontal')]
        if s_role:
            kids.append(tv('e_sub', s_role, 'text3', lines=2, w=220, gravity='center_horizontal', mt=4))
        else:
            kids.append(tv('e_sub', SMALL, 'text3', lines=1, w='match', gravity='center_horizontal', vis='gone'))
        layout('bw_empty_text_%s' % size, root([
            H([logo('e_logo', 14), ic('e_hicon', 'calendar', 14, 'text2', vis='gone'),
               tv('e_hcap', MICRO, 'text2', flex=1, ms=6, vis='gone')], gravity='center_vertical', w='match', h=16, mb=0),
            V(kids, gravity='center', w='match', flex=1, grav=None),
        ]))


# ====================================================================== MENU
def dish_row(p, i, with_kcal=True):
    kids = [tv('%s_d%d' % (p, i), BODY, 'text1', flex=1, w='wrap')]
    if with_kcal:
        kids.append(tv('%s_k%d' % (p, i), SMALL, 'text3', ms=8))
    return H(kids, gravity='center_vertical', w='match', mt=2 if i else 0, vis=None, id='%s_r%d' % (p, i))


def gen_menu():
    small = root([
        header('mn', 'sun'),
        tv('mn_main', DISPLAY, 'text1', lines=2, w='match'),
        tv('mn_sub', SMALL, 'text2', lines=1, w='match', mt=4),
        vspacer(),
        H([ic('mn_kicon', 'flame', 12, 'text2'), tv('mn_kcal', SMALL, 'text2', ms=4, flex=1)],
          id='mn_kcal_row', gravity='center_vertical', w='match'),
    ])

    def col(c):
        kids = [H([ic('mn_%sicon' % c, 'sun', 12, 'text3'), tv('mn_%scap' % c, CAPTION, 'text3', ms=4, flex=1)],
                  id='mn_%shead' % c, gravity='center_vertical', w='match', mb=6)]
        for i in range(3):
            kids.append(tv('mn_%sd%d' % (c, i), BODY, 'text1', w='match', mt=2 if i else 0))
        return V(kids, id='mn_%s' % c, flex=1, w='wrap', h='match')

    medium = root([
        header('mn', 'utensils', gap=8),
        H([col('c1'), div(True, id='mn_cdiv', ms=16, me=16), col('c2')], w='match', flex=1),
        H([ic('mn_kicon', 'flame', 12, 'text2'), tv('mn_total', SMALL, 'text2', ms=4, flex=1)],
          id='mn_kcal_row', gravity='center_vertical', w='match', mt=4),
    ])

    def section(p, n):
        kids = [H([ic('mn_%sicon' % p, 'sun', 12, 'text3'), tv('mn_%scap' % p, CAPTION, 'text3', ms=4, flex=1),
                   tv('mn_%stot' % p, SMALL, 'text2', ms=8)],
                  id='mn_%shead' % p, gravity='center_vertical', w='match', mb=6)]
        for i in range(n):
            kids.append(dish_row('mn_' + p, i))
        kids.append(tv('mn_%smore' % p, SMALL, 'text3', w='match', mt=2, vis='gone'))
        return V(kids, id='mn_%s' % p, w='match')

    large = root([
        header('mn', 'utensils', gap=12),
        section('a', 8),
        div(id='mn_div', mt=10, mb=10),
        section('b', 4),
        vspacer(),
        H([ic('mn_chipicon', 'flame', 14, 'text1'), tv('mn_chiplbl', BODY, 'text1', ms=8, flex=1),
           tv('mn_chiptot', BODY, 'text1', ms=8)],
          id='mn_chip', bg='@drawable/bw_chip12', pad=(0, 12, 0, 12), gravity='center_vertical', w='match', h=36, mt=4),
    ])
    sized('menu', small, medium, large)


# ====================================================================== TIMETABLE
def tt_row(i, h, first=True):
    p = 'tt_r%d' % i
    time_cell = F([
        tv(p + '_badge', BODY, 'inverse_fg', w=52, gravity='center', bg='@drawable/bw_badge_inverse8', pad=(2, 0, 2, 0),
           vis='gone', grav='center_vertical'),
        tv(p + '_t1', BODY, 'text1', w=52, gravity='center', grav='center_vertical', vis='gone'),
        tv(p + '_t2', BODY, 'text2', w=52, gravity='center', grav='center_vertical', vis='gone'),
    ], w=52, h='wrap')
    return H([
        time_cell,
        tv(p + '_title', BODY, 'text1', flex=1, ms=8),
        ic(p + '_pin', 'map-pin', 12, 'text2', ms=8),
        tv(p + '_room', SMALL, 'text2', ms=4),
    ], id=p, gravity='center_vertical', w='match', h=h, pad=(0, 8, 0, 8), mt=4 if i else 0)


def gen_timetable():
    small = root([
        header('tt', 'clock'),
        H([tv('tt_badge', BODY, 'inverse_fg', bg='@drawable/bw_badge_inverse8', pad=(2, 8, 2, 8)),
           tv('tt_in', SMALL, 'text3', ms=8, flex=1)], gravity='center_vertical', w='match'),
        tv('tt_title', TITLE, 'text1', lines=2, w='match', mt=8),
        vspacer(),
        H([ic('tt_pin', 'map-pin', 12, 'text2'), tv('tt_room', SMALL, 'text2', ms=4, flex=1)],
          id='tt_room_row', gravity='center_vertical', w='match'),
    ])
    medium = root([header('tt', 'clock', gap=12)] + [tt_row(i, 36) for i in range(2)])
    large = root([
        header('tt', 'calendar', gap=12),
        H([tv('tt_count', TITLE, 'text1', flex=1), tv('tt_in', SMALL, 'text2', ms=8)],
          gravity='center_vertical', w='match', mb=12),
    ] + [tt_row(i, 40) for i in range(4)] + [
        vspacer(),
        tv('tt_foot', SMALL, 'text3', lines=1, w='match', mt=6),
    ])
    sized('timetable', small, medium, large)


# ====================================================================== EVENTS
def badge(p, w, h, bg, day_role, mon_role, mon_mt=0, **lp):
    return V([
        tv(p + '_day', day_role, 'text1', gravity='center'),
        tv(p + '_mon', mon_role, 'text2', gravity='center', mt=mon_mt),
    ], id=p + '_badge', bg=bg, gravity='center', w=w, h=h, **lp)


def ev_row_medium(i):
    p = 'ev_r%d' % i
    return H([
        badge(p, 36, 36, '@drawable/bw_badge8', BDAY_S, BMON_S, 1),
        V([tv(p + '_title', BODY, 'text1', w='match'), tv(p + '_club', MICRO, 'text2', w='match')],
          flex=1, ms=10, gravity='center_vertical', w='wrap', h='wrap'),
        ic(p + '_cicon', 'clock', 12, 'text2', ms=10),
        tv(p + '_time', SMALL, 'text2', ms=4),
    ], id=p, gravity='center_vertical', w='match', h=36, mt=3 if i else 0)


def ev_row_large(i):
    p = 'ev_r%d' % i
    row = H([
        badge(p, 44, 48, '@drawable/bw_badge10', BDAY_L, BMON_L, 2),
        V([
            tv(p + '_title', QUESTION, 'text1', w='match'),
            tv(p + '_club', SMALL, 'text2', w='match', mt=1),
            H([ic(p + '_cicon', 'clock', 14, 'text2'), tv(p + '_time', SMALL, 'text2', ms=4),
               H([ic(p + '_vicon', 'map-pin', 14, 'text2'), tv(p + '_venue', SMALL, 'text2', ms=4, flex=1)],
                 id=p + '_vg', gravity='center_vertical', w='wrap', flex=1, ms=12)],
              gravity='center_vertical', w='match', mt=4),
        ], flex=1, ms=12, gravity='center_vertical', w='wrap', h='wrap'),
    ], id=p, gravity='center_vertical', w='match', flex=1)
    if i == 0:
        return [row]
    return [div(id='ev_div%d' % i), row]


def gen_events():
    small = root([
        H([ic('ev_hicon', 'calendar', 14, 'text2'), tv('ev_hcap', MICRO, 'text2', ms=6, flex=1)],
          gravity='center_vertical', w='match', h=16),
        H([tv('ev_day', HERO, 'text1'), tv('ev_mon', (12, 16, 0.08), 'text2', ms=6)], w='match', mt=10),
        vspacer(),
        tv('ev_title', BODYL, 'text1', lines=2, w='match'),
        H([ic('ev_cicon', 'clock', 12, 'text2'), tv('ev_time', MICRO, 'text2', ms=4, flex=1)],
          gravity='center_vertical', w='match', mt=6),
    ])
    hdr_m = H([logo('ev_logo', 14), tv('ev_hcap', MICRO, 'text2', ms=6, flex=1)], gravity='center_vertical', w='match', h=16, mb=10)
    medium = root([hdr_m] + [ev_row_medium(i) for i in range(3)])
    hdr_l = H([logo('ev_logo', 14), tv('ev_hcap', MICRO, 'text2', ms=6, flex=1), tv('ev_count', MICRO, 'text3', ms=8)],
              gravity='center_vertical', w='match', h=16)
    kids = [hdr_l, div(mt=12, mb=4)]
    for i in range(3):
        kids += ev_row_large(i)
    large = root(kids)
    sized('events', small, medium, large)


# ====================================================================== ANNOUNCEMENTS
def meta_row(p, role=MICRO, color='text3', **lp):
    return H([tv(p + '_urg', role, 'danger', vis='gone'), tv(p + '_meta', role, color, flex=1, ms=0)],
             gravity='center_vertical', w='match', **lp)


def gen_ann():
    small = root([
        H([ic('an_hicon', 'megaphone', 14, 'text2'), tv('an_hcap', MICRO, 'text2', ms=6, flex=1)],
          gravity='center_vertical', w='match', h=16),
        tv('an_title', QUESTION, 'text1', lines=4, w='match', mt=10),
        vspacer(),
        H([tv('an_urg', MICRO, 'danger', vis='gone'), tv('an_meta', MICRO, 'text2', flex=1)],
          gravity='center_vertical', w='match'),
    ])

    def row_m(i):
        p = 'an_r%d' % i
        return H([
            F(id=p + '_dot', bg='@drawable/bw_dot' if i == 0 else '@drawable/bw_dot_passive', w=4, h=4),
            F(id=p + '_dotd', bg='@drawable/bw_dot_danger', w=4, h=4, vis='gone'),
            V([tv(p + '_title', BODY, 'text1' if i == 0 else 'text2', w='match'), meta_row(p)],
              flex=1, ms=8, gravity='center_vertical', w='wrap', h='wrap'),
        ], id=p, gravity='center_vertical', w='match', h=36, mt=3 if i else 0)

    hdr_m = H([logo('an_logo', 14), tv('an_hcap', MICRO, 'text2', ms=6, flex=1)], gravity='center_vertical', w='match', h=16, mb=10)
    medium = root([hdr_m] + [row_m(i) for i in range(3)])

    def row_l(i):
        p = 'an_r%d' % i
        r = V([tv(p + '_title', BODYL, 'text1' if i == 0 else 'text2', lines=2, w='match'), meta_row(p, mt=3)],
              id=p, gravity='center_vertical', w='match', flex=1)
        return [r] if i == 0 else [div(id='an_div%d' % i), r]

    hdr_l = H([logo('an_logo', 14), tv('an_hcap', MICRO, 'text2', ms=6, flex=1), tv('an_last', MICRO, 'text3', ms=8)],
              gravity='center_vertical', w='match', h=16)
    kids = [hdr_l, div(mt=12, mb=4)]
    for i in range(4):
        kids += row_l(i)
    sized('announcements', small, medium, root(kids))


# ====================================================================== POLL
def opt_block(p, i, label_role, pct_role, bar_mt, mt):
    q = '%s_o%d' % (p, i)
    return V([
        H([tv(q + '_lbl', label_role, 'text1', flex=1),
           tv(q + '_pct1', pct_role, 'text1', ms=8, vis='gone'),
           tv(q + '_pct2', pct_role, 'text2', ms=8, vis='gone')],
          gravity='center_vertical', w='match'),
        bar(q + '_barA'), bar(q + '_barB', True),
    ], id=q, w='match', mt=mt)


def pill(id, **lp):
    return tv(id, (13, 16, 0), 'inverse_fg', bg='@drawable/bw_pill', pad=(6, 14, 6, 14), gravity='center', **lp)


def gen_poll():
    small = root([
        header('pl', 'vote'),
        tv('pl_q', QUESTION, 'text1', lines=3, w='match'),
        vspacer(),
        pill('pl_pill'),
        tv('pl_voted', BODY, 'text2', w='match', vis='gone'),
    ])
    opts = [opt_block('pl', i, SMALL, SMALL, 4, 0) for i in range(3)]
    for i, o in enumerate(opts):
        o.mt = 0
    gap = lambda: N('FrameLayout', {}, flex=1, w='match', h=0)
    right = V([opts[0], gap(), opts[1], gap(), opts[2], pill('pl_pill', mt=4, grav='start')],
              id='pl_right', flex=6, ms=16, w='wrap', h='match')
    left = V([tv('pl_q', QUESTION, 'text1', lines=3, w='match'), vspacer(),
              tv('pl_micro', MICRO, 'text3', lines=1, w='match')], flex=4, w='wrap', h='match')
    medium = root([header('pl', 'vote', gap=8), H([left, right], w='match', flex=1)])
    kids = [header('pl', 'vote', gap=12), tv('pl_q', TITLE, 'text1', lines=2, w='match', mb=16)]
    for i in range(4):
        kids.append(opt_block('pl', i, BODY, BODY, 6, 14 if i else 0))
    kids += [pill('pl_pill', mt=14, grav='start'), vspacer(),
             H([ic('pl_lock', 'lock', 12, 'text2'), tv('pl_secret', SMALL, 'text2', ms=4, flex=1),
                tv('pl_detail', SMALL, 'text1', ms=8), ic('pl_chev', 'chevron-right', 12, 'text1')],
               gravity='center_vertical', w='match', id='pl_bottom')]
    sized('poll', small, medium, root(kids))


# ====================================================================== QUICK ACCESS
def qa_tile(i, ic_size, radius_bg, lbl_mt, ms):
    return V([ic('qa_i%d' % i, 'search', ic_size, 'text1'),
              tv('qa_l%d' % i, MICRO, 'text2', w='match', gravity='center', mt=lbl_mt)],
             id='qa_t%d' % i, bg=radius_bg, gravity='center', flex=1, w='wrap', h='match', ms=ms)


def qa_grid(n_cols, rows, ic_size, bg, lbl_mt, flex_rows=True):
    out = []
    for r in range(rows):
        out.append(H([qa_tile(r * n_cols + c, ic_size, bg, lbl_mt, 8 if c else 0) for c in range(n_cols)],
                     w='match', flex=1, mt=8 if r else 0))
    return out


def gen_quick():
    small = root(qa_grid(2, 2, 22, '@drawable/bw_chip12', 6), pad=12)
    medium = root([header('qa', 'search', gap=10)] + qa_grid(4, 2, 18, '@drawable/bw_chip14', 4))
    large = root([header('qa', None, gap=4), tv('qa_heading', TITLE, 'text1', w='match'),
                  tv('qa_sub', SMALL, 'text3', w='match', mb=14)] + qa_grid(4, 2, 24, '@drawable/bw_chip14', 6))
    sized('quickaccess', small, medium, large)


# ====================================================================== SOCIAL
def gen_social():
    small = root([
        header('sc', 'message-square'),
        tv('sc_num', NUMBER, 'text1', w='match'),
        tv('sc_sub', SMALL, 'text2', lines=2, w='match'),
        vspacer(),
        H([ic('sc_bicon', 'bell', 12, 'text2'), tv('sc_n2', SMALL, 'text2', ms=4),
           ic('sc_hicon2', 'heart', 12, 'heart', ms=12), tv('sc_n3', SMALL, 'text2', ms=4, flex=1)],
          gravity='center_vertical', w='match'),
    ])

    def col(i, icon, color):
        return V([ic('sc_c%d_ic' % i, icon, 18, color), tv('sc_c%d_n' % i, NUMBER, 'text1', w='match', mt=6),
                  tv('sc_c%d_l' % i, SMALL, 'text2', w='match')],
                 id='sc_c%d' % i, flex=1, w='wrap', h='wrap', ms=12 if i else 0, me=12 if i < 2 else 0)

    medium = root([
        header('sc', 'message-circle', gap=12),
        H([col(0, 'message-square', 'text2'), div(True), col(1, 'bell', 'text2'), div(True),
           col(2, 'heart', 'heart')], w='match', flex=1),
    ])
    # bolucu margin'lari: kolon margin'i dar tutulsun; dogrudan 12 aralik
    def row(i, icon, color):
        p = 'sc_r%d' % i
        return H([
            ic(p + '_ic', icon, 22, color),
            V([tv(p + '_l', BODY, 'text1', w='match'), tv(p + '_s', MICRO, 'text3', w='match')],
              flex=1, ms=12, gravity='center_vertical', w='wrap', h='wrap'),
            tv(p + '_n', NUMROW, 'text1', ms=12),
        ], id=p, bg='@drawable/bw_chip14', pad=(0, 14, 0, 14), gravity='center_vertical', w='match', h=64, mt=8 if i else 0)

    large = root([
        header('sc', 'message-circle', gap=4),
        tv('sc_heading', TITLE, 'text1', w='match'),
        tv('sc_note', SMALL, 'text3', w='match', mb=14),
        row(0, 'message-square', 'text2'), row(1, 'bell', 'text2'), row(2, 'heart', 'heart'),
    ])
    sized('social', small, medium, large)


def main():
    drawables()
    gen_common()
    gen_menu()
    gen_timetable()
    gen_events()
    gen_ann()
    gen_poll()
    gen_quick()
    gen_social()
    print('layouts done')


if __name__ == '__main__':
    main()
