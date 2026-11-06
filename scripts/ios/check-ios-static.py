#!/usr/bin/env python3
"""iOS dosya duzeyi on kontrol (macOS/Xcode GEREKTIRMEZ; Windows'ta da calisir).

Kullanim (repo kokunden):  python -I -X utf8 scripts/ios/check-ios-static.py
Cikis kodu: 0 = tum kontroller gecti (uyarilar olabilir), 1 = en az bir HATA.

Bu betik Xcode'un yerine GECMEZ: yalnizca plist/pbxproj/varlik tutarliligini ve App Store'un en sik
reddettigi dosya duzeyi hatalari yakalar. Derleme/imza/yukleme macOS'ta dogrulanir (docs/IOS_RELEASE.md).
"""
import glob
import json
import os
import plistlib
import re
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
IOS = os.path.join(ROOT, 'mobile', 'ios')
RUNNER = os.path.join(IOS, 'Runner')

errors = []
warnings = []


def ok(msg):
    print('[OK]    ' + msg)


def bad(msg):
    print('[HATA]  ' + msg)
    errors.append(msg)


def warn(msg):
    print('[UYARI] ' + msg)
    warnings.append(msg)


def read(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()


def load_plist(path):
    with open(path, 'rb') as f:
        return plistlib.load(f)


# Kullanilan izinler -> Info.plist anahtari (eklenti/davranis esleme: docs/IOS_RELEASE.md bolum 3)
REQUIRED_USAGE = [
    'NSCameraUsageDescription',        # mobile_scanner, camera, image_picker (kamera)
    'NSMicrophoneUsageDescription',    # video cekimi (image_picker/camera, ses)
    'NSPhotoLibraryUsageDescription',  # photo_manager, image_picker (galeri)
    'NSPhotoLibraryAddUsageDescription',  # gal (galeriye kaydet)
    'NSContactsUsageDescription',      # flutter_contacts (rehber eslestirme)
    'NSCalendarsFullAccessUsageDescription',  # BuCalendarBridge (iOS 17+, akademik takvimi cihaz takvimine yazma)
    'NSCalendarsUsageDescription',     # ayni islev, iOS 15-16 (dagitim hedefi 15.0)
]
# Uygulamada KARSILIGI OLMAYAN izin anahtarlari: eklenirse App Review "kullanilmayan izin" sorar
FORBIDDEN_USAGE = [
    'NSLocationWhenInUseUsageDescription', 'NSLocationAlwaysAndWhenInUseUsageDescription',
    'NSLocationAlwaysUsageDescription', 'NSUserTrackingUsageDescription', 'NSBluetoothAlwaysUsageDescription',
    'NSRemindersUsageDescription', 'NSSpeechRecognitionUsageDescription',
    'NSMotionUsageDescription', 'NSFaceIDUsageDescription', 'NSHealthShareUsageDescription',
]
ALLOWED_REASONS = {
    'NSPrivacyAccessedAPICategoryFileTimestamp': {'DDA9.1', 'C617.1', '3B52.1', '0A2A.1'},
    'NSPrivacyAccessedAPICategorySystemBootTime': {'35F9.1'},
    'NSPrivacyAccessedAPICategoryDiskSpace': {'85F4.1', 'E174.1', '7D9E.1', 'B728.1'},
    'NSPrivacyAccessedAPICategoryUserDefaults': {'CA92.1', '1C8F.1', 'C56D.1', 'AC6B.1'},
    'NSPrivacyAccessedAPICategoryActiveKeyboards': {'3EC4.1', '54BD.1'},
}
LANGS = ['tr', 'en', 'ar']


def check_info_plist():
    path = os.path.join(RUNNER, 'Info.plist')
    info = load_plist(path)
    ok('Info.plist ayrisiyor')
    for k in REQUIRED_USAGE:
        v = info.get(k, '')
        if not isinstance(v, str) or len(v.strip()) < 30:
            bad(f'Info.plist: {k} eksik/cok kisa (en az bir cumle aciklama)')
        else:
            ok(f'Info.plist: {k} ({len(v)} karakter)')
    for k in FORBIDDEN_USAGE:
        if k in info:
            bad(f'Info.plist: {k} var ama uygulamada karsiligi yok (kaldirin)')
    if info.get('ITSAppUsesNonExemptEncryption') is False:
        ok('ITSAppUsesNonExemptEncryption=false (gerekce: docs/IOS_RELEASE.md bolum 4)')
    else:
        bad('ITSAppUsesNonExemptEncryption=false olmali (aksi halde her yuklemede ihracat sorusu cikar)')
    if sorted(info.get('CFBundleLocalizations', [])) == sorted(LANGS):
        ok('CFBundleLocalizations = tr, en, ar')
    else:
        bad('CFBundleLocalizations tr, en, ar olmali')
    if info.get('UIBackgroundModes') == ['remote-notification']:
        ok('UIBackgroundModes = remote-notification')
    else:
        bad('UIBackgroundModes yalniz remote-notification olmali (baska mod App Review gerekcesi ister)')
    # Paylasim baglantisi (derin baglanti): Flutter'in kendi yonlendirmesi kapali, `bukampus` ozel semasi kayitli.
    if info.get('FlutterDeepLinkingEnabled') is False:
        ok('FlutterDeepLinkingEnabled=false (derin baglantiyi app_links isler)')
    else:
        bad('FlutterDeepLinkingEnabled=false olmali (aksi halde Flutter /s/... yolunu rota sanir)')
    schemes = [s for t in info.get('CFBundleURLTypes', []) for s in t.get('CFBundleURLSchemes', [])]
    if 'bukampus' in schemes:
        ok('CFBundleURLTypes: bukampus:// ozel semasi kayitli')
    else:
        bad('CFBundleURLTypes: bukampus ozel semasi eksik (paylasim baglantisi yedegi)')
    # Google ile giris (iOS): GIDClientID + ters istemci kimligi URL semasi birbiriyle tutarli olmali.
    gid = info.get('GIDClientID', '')
    if gid.endswith('.apps.googleusercontent.com'):
        rev = 'com.googleusercontent.apps.' + gid[: -len('.apps.googleusercontent.com')]
        if rev in schemes:
            ok('Google girisi: GIDClientID + ters kimlik URL semasi tutarli')
        else:
            bad('Google girisi: GIDClientID var ama ters kimlik URL semasi (com.googleusercontent.apps.<no>) CFBundleURLTypes icinde yok')
    else:
        warn('Google girisi: Info.plist GIDClientID tanimsiz/gecersiz (iOS Google dugmesi calismaz)')
    if 'FirebaseAppDelegateProxyEnabled' in info:
        bad('FirebaseAppDelegateProxyEnabled tanimli: kaldirin (swizzling acik kalmali, bkz. docs/MOBILE_PUSH.md)')
    else:
        ok('FirebaseAppDelegateProxyEnabled tanimsiz (swizzling acik)')
    if info.get('UISupportedInterfaceOrientations') == ['UIInterfaceOrientationPortrait']:
        ok('iPhone yonlendirmesi: yalniz dikey (main.dart telefonda dikey kilit ile uyumlu)')
    else:
        warn('iPhone yonlendirmesi yalniz dikey degil; main.dart telefonda dikey kilitliyor')
    ats = info.get('NSAppTransportSecurity', {})
    if ats.get('NSAllowsArbitraryLoads') or ats.get('NSAllowsArbitraryLoadsInWebContent'):
        bad('ATS: NSAllowsArbitraryLoads* acik (App Review gerekce ister; https zorunlu)')
    else:
        ok('ATS: genel istisna yok (yalniz NSAllowsLocalNetworking olabilir)')
    if 'LSApplicationQueriesSchemes' in info:
        warn('LSApplicationQueriesSchemes tanimli; kodda canLaunchUrl yoksa gereksiz')
    if info.get('CFBundleDisplayName'):
        ok('CFBundleDisplayName = ' + info['CFBundleDisplayName'].encode('ascii', 'replace').decode())
    return info


def parse_strings(path):
    out = {}
    for m in re.finditer(r'^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$', read(path), re.M):
        out[m.group(1)] = m.group(2)
    return out


def check_strings(info):
    base_usage = [k for k in info if k.endswith('UsageDescription')]
    for lang in LANGS:
        p = os.path.join(RUNNER, f'{lang}.lproj', 'InfoPlist.strings')
        if not os.path.isfile(p):
            bad(f'{lang}.lproj/InfoPlist.strings yok')
            continue
        raw = read(p)
        if raw.startswith('﻿'):
            bad(f'{lang}.lproj/InfoPlist.strings BOM iceriyor')
        s = parse_strings(p)
        missing = [k for k in base_usage + ['CFBundleDisplayName'] if k not in s]
        if missing:
            bad(f'{lang}.lproj/InfoPlist.strings eksik anahtarlar: {missing}')
        else:
            ok(f'{lang}.lproj/InfoPlist.strings tum izin anahtarlarini iceriyor ({len(s)} satir)')
        for k, v in s.items():
            if k.endswith('UsageDescription') and len(v.strip()) < 30:
                bad(f'{lang}: {k} cok kisa')
    tr = parse_strings(os.path.join(RUNNER, 'tr.lproj', 'InfoPlist.strings'))
    for k in base_usage:
        if tr.get(k) and tr[k] != info.get(k):
            warn(f'tr.lproj {k} Info.plist varsayilanindan farkli (ikisi ayni tutulur)')


def check_entitlements():
    for name, env in (('Runner.entitlements', 'development'), ('RunnerRelease.entitlements', 'production')):
        d = load_plist(os.path.join(RUNNER, name))
        if d.get('aps-environment') == env:
            ok(f'{name}: aps-environment={env}')
        else:
            bad(f'{name}: aps-environment={env} olmali')
        # time-sensitive ve associated-domains yetkileri KASITLI olarak YOK: App ID'de (developer.apple.com) bu iki yetenek
        # acilip profil yenilenmeden imza hatasi verir (Codemagic: "Provisioning profile ... doesn't include ...").
        # Acilinca geri eklenir (bkz. docs/IOS_RELEASE.md). Yokken bildirim normal duzeyde teslim edilir (kod uyumlu).
        for key in ('com.apple.developer.usernotifications.time-sensitive', 'com.apple.developer.associated-domains'):
            if key in d:
                bad(f'{name}: {key} App ID yetkisi acilmadan eklenmemeli (imza hatasi)')
            else:
                ok(f'{name}: {key} yok (App ID yetkisi acilana kadar kapali)')
    x = read(os.path.join(IOS, 'Flutter', 'BuPush.xcconfig.example'))
    if 'RunnerRelease.entitlements' in x and 'config=Release' in x:
        ok('BuPush.xcconfig.example: Release -> RunnerRelease.entitlements (production)')
    else:
        bad('BuPush.xcconfig.example Release icin RunnerRelease.entitlements baglamali')


def check_push_categories():
    """AppDelegate.registerPushCategories anahtarlari == NotificationContent Info.plist kategori listesi."""
    app = read(os.path.join(RUNNER, 'AppDelegate.swift'))
    body = app[app.index('let definitions'):app.index('setNotificationCategories')]
    keys = set(re.findall(r'^\s*"([A-Z_]+)":', body, re.M)) | set(re.findall(r',\s*"([A-Z_]+)":', body))
    plist = load_plist(os.path.join(IOS, 'NotificationContent', 'Info.plist'))
    cats = plist['NSExtension']['NSExtensionAttributes']['UNNotificationExtensionCategory']
    declared = {c[3:] for c in cats if c.startswith('BU_')}
    if keys == declared and keys:
        ok(f'Push kategorileri: AppDelegate ({len(keys)}) == NotificationContent Info.plist')
    else:
        bad(f'Push kategorileri uyusmuyor: yalniz AppDelegate {sorted(keys - declared)}, yalniz Info.plist {sorted(declared - keys)}')
    for name in ('NotificationService/NotificationService.swift', 'NotificationContent/NotificationViewController.swift'):
        (ok if os.path.isfile(os.path.join(IOS, name)) else bad)(f'{name} diskte')


def check_privacy():
    d = load_plist(os.path.join(RUNNER, 'PrivacyInfo.xcprivacy'))
    if d.get('NSPrivacyTracking') is False and d.get('NSPrivacyTrackingDomains') == []:
        ok('PrivacyInfo: NSPrivacyTracking=false, izleme alan adi yok')
    else:
        bad('PrivacyInfo: NSPrivacyTracking=false ve NSPrivacyTrackingDomains bos olmali')
    for e in d.get('NSPrivacyCollectedDataTypes', []):
        if e.get('NSPrivacyCollectedDataTypeTracking') is not False:
            bad('PrivacyInfo: ' + e.get('NSPrivacyCollectedDataType', '?') + ' Tracking=false olmali')
        if not e.get('NSPrivacyCollectedDataTypePurposes'):
            bad('PrivacyInfo: ' + e.get('NSPrivacyCollectedDataType', '?') + ' amac listesi bos')
    ok(f"PrivacyInfo: {len(d.get('NSPrivacyCollectedDataTypes', []))} veri turu bildirilmis")
    for api in d.get('NSPrivacyAccessedAPITypes', []):
        cat = api.get('NSPrivacyAccessedAPIType')
        allowed = ALLOWED_REASONS.get(cat)
        if allowed is None:
            bad(f'PrivacyInfo: bilinmeyen API kategorisi {cat}')
            continue
        for r in api.get('NSPrivacyAccessedAPITypeReasons', []):
            if r not in allowed:
                bad(f'PrivacyInfo: {cat} icin gecersiz neden kodu {r}')
        ok(f"PrivacyInfo: {cat} -> {api.get('NSPrivacyAccessedAPITypeReasons')}")


def check_pbxproj():
    s = read(os.path.join(IOS, 'Runner.xcodeproj', 'project.pbxproj'))
    checks = [
        ('PrivacyInfo.xcprivacy in Resources', 'PrivacyInfo.xcprivacy Resources fazinda'),
        ('InfoPlist.strings in Resources', 'InfoPlist.strings (tr/en/ar) Resources fazinda'),
        ('BuNativeBridge.swift in Sources', 'BuNativeBridge.swift Sources fazinda'),
        ('BuCalendarAlarmBridge.swift in Sources', 'BuCalendarAlarmBridge.swift Sources fazinda'),
        ('Bundle GoogleService-Info.plist (optional)', 'GoogleService-Info.plist paketleme fazi'),
    ]
    for needle, label in checks:
        (ok if needle in s else bad)(label + ('' if needle in s else ' YOK'))
    n_ent = len(re.findall(r'CODE_SIGN_ENTITLEMENTS = "\$\(BU_PUSH_ENTITLEMENTS\)"', s))
    (ok if n_ent == 3 else bad)(f'CODE_SIGN_ENTITLEMENTS 3 yapilandirmada ({n_ent}/3)')
    n_fam = len(re.findall(r'TARGETED_DEVICE_FAMILY = 1;', s))
    (ok if n_fam >= 3 else bad)(f'Runner hedefi iPhone-only (TARGETED_DEVICE_FAMILY=1) {n_fam}/3')
    m = re.search(r'knownRegions = \(([^)]*)\)', s)
    regions = set(re.findall(r'\b(\w+)\b', m.group(1))) if m else set()
    (ok if {'tr', 'en', 'ar'} <= regions else bad)('knownRegions tr, en, ar iceriyor')
    # Uzantilarin ayri bundle id'leri vardir; yalniz Runner plist'ini kullanan
    # buildSettings bloklarini denetle (Debug, Release, Profile).
    settings = re.findall(r'buildSettings\s*=\s*\{([^{}]*)\}', s, re.S)
    runner_settings = [b for b in settings if re.search(
        r'\bINFOPLIST_FILE\s*=\s*"?Runner/Info\.plist"?\s*;', b)]
    (ok if len(runner_settings) == 3 else bad)(
        f'Runner buildSettings yapilandirmalari ({len(runner_settings)}/3)')
    ids = set()
    for block in runner_settings:
        match = re.search(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([A-Za-z0-9.\-]+)"?\s*;', block)
        if match:
            ids.add(match.group(1))
        else:
            bad('Runner buildSettings: PRODUCT_BUNDLE_IDENTIFIER eksik')
    if len(ids) == 1:
        ok('Bundle id (tek deger): ' + next(iter(ids)))
    else:
        bad(f'Runner hedefinde birden fazla bundle id: {sorted(ids)}')
    if 'Debug.xcconfig' in s and 'Release.xcconfig' in s:
        ok('Debug/Release xcconfig baglantili')
    # dosya var mi
    for name in ('BuNativeBridge.swift', 'BuCalendarAlarmBridge.swift', 'PrivacyInfo.xcprivacy', 'AppDelegate.swift', 'SceneDelegate.swift'):
        (ok if os.path.isfile(os.path.join(RUNNER, name)) else bad)(f'Runner/{name} diskte')
    return next(iter(ids)) if len(ids) == 1 else None


def png_size_alpha(path):
    with open(path, 'rb') as f:
        d = f.read(64)
    w, h, _bd, ct = struct.unpack('>IIBB', d[16:26])
    return w, h, ct in (4, 6)


def check_icons():
    # Tek boyut (Xcode 14+) AppIcon: acik + koyu (iOS 18) + tinted 1024 px, hepsi alfasiz (App Store Connect reddeder).
    base = os.path.join(RUNNER, 'Assets.xcassets', 'AppIcon.appiconset')
    contents = json.loads(read(os.path.join(base, 'Contents.json')))
    files = [i.get('filename') for i in contents.get('images', [])]
    if len(files) != 3:
        bad(f'AppIcon Contents.json 3 gorsel (acik/koyu/tinted) icermeli: {files}')
    for fn in files:
        path = os.path.join(base, fn or '')
        if not os.path.isfile(path):
            bad(f'AppIcon dosyasi yok: {fn}')
            continue
        w, h, alpha = png_size_alpha(path)
        if (w, h) != (1024, 1024):
            bad(f'{fn} 1024x1024 olmali ({w}x{h})')
        elif alpha:
            bad(f'{fn} ALFA kanali iceriyor: App Store Connect reddeder')
        else:
            ok(f'{fn} 1024x1024, alfasiz')
    vals = sorted(a['value'] for i in contents.get('images', []) for a in i.get('appearances', []))
    (ok if vals == ['dark', 'tinted'] else bad)(f'AppIcon gorunumleri (dark, tinted): {vals}')
    ls = os.path.join(RUNNER, 'Base.lproj', 'LaunchScreen.storyboard')
    t = read(ls)
    cs = os.path.join(RUNNER, 'Assets.xcassets', 'LaunchBackground.colorset', 'Contents.json')
    if 'name="LaunchBackground"' in t and os.path.isfile(cs):
        ok('LaunchScreen: acik/koyu zemin (LaunchBackground renk kumesi) + acik/koyu logo (LaunchImage)')
    else:
        warn('LaunchScreen LaunchBackground renk kumesine bagli degil')


def check_google_plist(bundle):
    p = os.path.join(RUNNER, 'GoogleService-Info.plist')
    if not os.path.isfile(p):
        warn('GoogleService-Info.plist yok (beklenen: CI gizli degiskenden yazar; yerelde push kapali kalir)')
        return
    d = load_plist(p)
    if d.get('BUNDLE_ID') == bundle:
        ok('GoogleService-Info.plist BUNDLE_ID Xcode bundle id ile eslesiyor')
    else:
        bad(f"GoogleService-Info.plist BUNDLE_ID ({d.get('BUNDLE_ID')}) != {bundle}")
    for k in ('GCM_SENDER_ID', 'GOOGLE_APP_ID', 'API_KEY', 'PROJECT_ID'):
        (ok if k in d else bad)(f'GoogleService-Info.plist {k} ' + ('var' if k in d else 'EKSIK'))


# ---------------------------------------------------------------------------------------------------------------------
# Ana ekran widget uzantisi (BUWidgets): pbxproj yapisi, bundle id, App Group, kaynaklar, sozlesme ornekleri
# ---------------------------------------------------------------------------------------------------------------------
WIDGETS = os.path.join(IOS, 'BUWidgets')
WIDGET_BUNDLE = 'tr.com.bukampus.app.widgets'
APP_GROUP = 'group.tr.com.bukampus.app'
WIDGET_KINDS = ['BUMenuWidget', 'BUTimetableWidget', 'BUEventsWidget', 'BUAnnouncementsWidget', 'BUPollWidget',
                'BUQuickAccessWidget', 'BUSocialWidget']
EXAMPLES = os.path.join(ROOT, 'design', 'widget-previews', 'examples')


def parse_pbx(text):
    """Eski bicim (OpenStep) plist ayristirici: /* */ yorumlari atilir, tekrar eden anahtar = hata."""
    pos = [0]
    n = len(text)
    bare = re.compile(r'[A-Za-z0-9_$./\-\[\]*=+@<>:]+')

    def skip():
        while pos[0] < n:
            c = text[pos[0]]
            if c in ' \t\r\n':
                pos[0] += 1
            elif text.startswith('/*', pos[0]):
                pos[0] = text.index('*/', pos[0]) + 2
            elif text.startswith('//', pos[0]):
                e = text.find('\n', pos[0])
                pos[0] = n if e < 0 else e + 1
            else:
                break

    def string():
        if text[pos[0]] == '"':
            pos[0] += 1
            out = []
            while text[pos[0]] != '"':
                if text[pos[0]] == '\\':
                    out.append(text[pos[0]:pos[0] + 2])
                    pos[0] += 2
                else:
                    out.append(text[pos[0]])
                    pos[0] += 1
            pos[0] += 1
            return ''.join(out)
        m = bare.match(text, pos[0])
        if not m:
            raise ValueError('beklenmeyen karakter %r @%d' % (text[pos[0]], pos[0]))
        pos[0] = m.end()
        return m.group(0)

    def value():
        skip()
        c = text[pos[0]]
        if c == '{':
            pos[0] += 1
            d = {}
            while True:
                skip()
                if text[pos[0]] == '}':
                    pos[0] += 1
                    return d
                k = string()
                skip()
                if text[pos[0]] != '=':
                    raise ValueError('= bekleniyordu @%d' % pos[0])
                pos[0] += 1
                v = value()
                skip()
                if text[pos[0]] != ';':
                    raise ValueError('; bekleniyordu @%d' % pos[0])
                pos[0] += 1
                if k in d:
                    raise ValueError('tekrar eden anahtar: ' + k)
                d[k] = v
        if c == '(':
            pos[0] += 1
            a = []
            while True:
                skip()
                if text[pos[0]] == ')':
                    pos[0] += 1
                    return a
                a.append(value())
                skip()
                if text[pos[0]] == ',':
                    pos[0] += 1
        return string()

    skip()
    root = value()
    skip()
    if pos[0] != n:
        raise ValueError('fazladan icerik @%d' % pos[0])
    return root


def pbx_refs(v, out):
    """Degerlerdeki 24 haneli onaltili kimlikleri toplar."""
    if isinstance(v, dict):
        for x in v.values():
            pbx_refs(x, out)
    elif isinstance(v, list):
        for x in v:
            pbx_refs(x, out)
    elif isinstance(v, str) and re.fullmatch(r'[0-9A-F]{24}', v):
        out.add(v)


def check_widget_pbx():
    path = os.path.join(IOS, 'Runner.xcodeproj', 'project.pbxproj')
    try:
        root = parse_pbx(read(path))
    except Exception as e:  # noqa: BLE001
        bad('pbxproj ayrisamadi: %s' % e)
        return
    ok('pbxproj eski-bicim plist olarak ayrisiyor (parantez/noktalivirgul dengeli, anahtarlar benzersiz)')
    objs = root.get('objects', {})
    refs = set()
    for v in objs.values():
        pbx_refs(v, refs)
    pbx_refs({'r': root.get('rootObject')}, refs)
    missing = sorted(r for r in refs if r not in objs)
    if missing:
        bad('pbxproj: tanimsiz referans %s' % missing[:5])
    else:
        ok('pbxproj: tum kimlik referanslari tanimli')
    targets = {o.get('name'): (k, o) for k, o in objs.items() if o.get('isa') == 'PBXNativeTarget'}
    if 'BUWidgets' not in targets:
        bad('pbxproj: BUWidgets hedefi yok')
        return
    tid, t = targets['BUWidgets']
    (ok if t.get('productType') == 'com.apple.product-type.app-extension' else bad)('BUWidgets hedefi app-extension')
    proj = objs[root['rootObject']]
    (ok if tid in proj.get('targets', []) else bad)('BUWidgets proje hedef listesinde')
    cl = objs[t['buildConfigurationList']]
    cfgs = {objs[c]['name']: objs[c]['buildSettings'] for c in cl['buildConfigurations']}
    (ok if set(cfgs) == {'Debug', 'Release', 'Profile'} else bad)('BUWidgets Debug/Release/Profile yapilandirmalari')
    runner_t = targets['Runner'][1]
    rcl = objs[runner_t['buildConfigurationList']]
    rset = {objs[c]['name']: objs[c]['buildSettings'] for c in rcl['buildConfigurations']}
    for name, bs in cfgs.items():
        if bs.get('PRODUCT_BUNDLE_IDENTIFIER') != WIDGET_BUNDLE:
            bad('BUWidgets %s: bundle id %s olmali' % (name, WIDGET_BUNDLE))
        if bs.get('INFOPLIST_FILE') != 'BUWidgets/Info.plist':
            bad('BUWidgets %s: INFOPLIST_FILE' % name)
        if bs.get('CODE_SIGN_ENTITLEMENTS', '').strip('"') != '$(BU_WIDGETS_ENTITLEMENTS)':
            bad('BUWidgets %s: CODE_SIGN_ENTITLEMENTS $(BU_WIDGETS_ENTITLEMENTS) olmali' % name)
        if bs.get('IPHONEOS_DEPLOYMENT_TARGET') != '15.0':
            bad('BUWidgets %s: dagitim hedefi 15.0 olmali (Runner ile ayni)' % name)
        if bs.get('MARKETING_VERSION', '').strip('"') != '$(FLUTTER_BUILD_NAME)' or bs.get('CURRENT_PROJECT_VERSION', '').strip('"') != '$(FLUTTER_BUILD_NUMBER)':
            bad('BUWidgets %s: surum Runner ile ayni (FLUTTER_BUILD_NAME/NUMBER) olmali' % name)
        if bs.get('SKIP_INSTALL') != 'YES' or bs.get('APPLICATION_EXTENSION_API_ONLY') != 'YES':
            bad('BUWidgets %s: SKIP_INSTALL/APPLICATION_EXTENSION_API_ONLY YES olmali' % name)
        if bs.get('SWIFT_VERSION') != '5.0':
            bad('BUWidgets %s: SWIFT_VERSION 5.0' % name)
        if rset.get(name, {}).get('IPHONEOS_DEPLOYMENT_TARGET', '15.0') != bs.get('IPHONEOS_DEPLOYMENT_TARGET'):
            bad('BUWidgets %s: Runner dagitim hedefiyle farkli' % name)
    ok('BUWidgets yapilandirmalari: bundle id %s, iOS 15.0, ortak surum, SKIP_INSTALL, uzanti-guvenli API' % WIDGET_BUNDLE)
    phases = [objs[p] for p in t['buildPhases']]
    kinds = [p['isa'] for p in phases]
    (ok if kinds == ['PBXSourcesBuildPhase', 'PBXFrameworksBuildPhase', 'PBXResourcesBuildPhase'] else bad)('BUWidgets: Sources/Frameworks/Resources fazlari')
    src_files = {objs[objs[b]['fileRef']]['path'] for b in phases[0]['files']}
    disk = set()
    for _dp, _dn, fn in os.walk(WIDGETS):
        for f in fn:
            if f.endswith('.swift'):
                disk.add(f)
    if src_files == disk:
        ok('BUWidgets Sources == diskteki .swift dosyalari (%d)' % len(disk))
    else:
        bad('BUWidgets Sources farki: fazla=%s eksik=%s' % (sorted(src_files - disk), sorted(disk - src_files)))
    (ok if 'BuWidgetTokens.swift' in src_files else bad)('Shared/BuWidgetTokens.swift BUWidgets Sources fazinda')
    rsrc = [objs[p] for p in runner_t['buildPhases'] if objs[p]['isa'] == 'PBXSourcesBuildPhase'][0]
    rfiles = {objs[objs[b]['fileRef']]['path'] for b in rsrc['files']}
    (ok if 'BuWidgetTokens.swift' not in rfiles else bad)('BuWidgetTokens.swift Runner hedefine EKLENMEMIS (yalniz uzanti)')
    res = [objs[b]['fileRef'] for b in phases[2]['files']]
    names = {objs[r].get('path') or objs[r].get('name') for r in res}
    (ok if {'Assets.xcassets', 'Localizable.strings'} <= names else bad)('BUWidgets Resources: Assets.xcassets + Localizable.strings')
    embed = [o for o in objs.values() if o.get('isa') == 'PBXCopyFilesBuildPhase' and o.get('name') == 'Embed App Extensions']
    prods = {objs[objs[b]['fileRef']]['path'] for e in embed for b in e['files']}
    (ok if 'BUWidgets.appex' in prods else bad)('BUWidgets.appex "Embed App Extensions" fazinda (Runner)')
    deps = [objs[d] for d in runner_t.get('dependencies', [])]
    (ok if any(d.get('target') == tid for d in deps) else bad)("Runner hedefi BUWidgets'a bagimli")


def check_widget_files():
    for f in ('Info.plist', 'BUWidgets.entitlements', 'Shared/BuWidgetTokens.swift', 'BuIconData.swift', 'BuSampleData.swift',
              'BUWidgetsBundle.swift', 'Assets.xcassets/BuLogo.imageset/Contents.json',
              'Assets.xcassets/BuLogo.imageset/logo_light.png', 'Assets.xcassets/BuLogo.imageset/logo_dark.png'):
        (ok if os.path.isfile(os.path.join(WIDGETS, f)) else bad)('BUWidgets/%s diskte' % f)
    info = load_plist(os.path.join(WIDGETS, 'Info.plist'))
    ext = info.get('NSExtension', {})
    (ok if ext.get('NSExtensionPointIdentifier') == 'com.apple.widgetkit-extension' else bad)('BUWidgets Info.plist: NSExtensionPointIdentifier = com.apple.widgetkit-extension')
    (ok if 'NSExtensionPrincipalClass' not in ext else bad)('BUWidgets Info.plist: PrincipalClass yok (@main WidgetBundle)')
    (ok if info.get('CFBundlePackageType') == 'XPC!' else bad)('BUWidgets Info.plist: CFBundlePackageType XPC!')
    (ok if sorted(info.get('CFBundleLocalizations', [])) == sorted(LANGS) else bad)('BUWidgets Info.plist: CFBundleLocalizations tr, en, ar')
    for rel in ('BUWidgets/BUWidgets.entitlements', 'Runner/Runner.entitlements', 'Runner/RunnerRelease.entitlements'):
        d = load_plist(os.path.join(IOS, rel))
        (ok if d.get('com.apple.security.application-groups') == [APP_GROUP] else bad)('%s: App Group %s' % (rel, APP_GROUP))
    d = load_plist(os.path.join(RUNNER, 'Runner.entitlements'))
    (ok if d.get('com.apple.developer.applesignin') == ['Default'] else bad)('Runner.entitlements: applesignin korunmus')
    x = read(os.path.join(IOS, 'Flutter', 'BuPush.xcconfig.example'))
    (ok if 'BU_WIDGETS_ENTITLEMENTS = BUWidgets/BUWidgets.entitlements' in x else bad)('BuPush.xcconfig.example: BU_WIDGETS_ENTITLEMENTS')
    all_swift = ''
    for dp, _dn, fn in os.walk(WIDGETS):
        for f in fn:
            if f.endswith('.swift'):
                src = read(os.path.join(dp, f))
                if src.startswith('﻿'):
                    bad('%s BOM iceriyor' % f)
                if f != 'BuWidgetTokens.swift':
                    all_swift += src
    for k in WIDGET_KINDS:
        (ok if ('"%s"' % k) in all_swift else bad)('kind %s tanimli' % k)
    (ok if '@main' in all_swift and 'WidgetBundle' in all_swift else bad)('@main WidgetBundle var')
    for w in re.findall(r'weight:\s*\.(\w+)', all_swift):
        if w != 'regular':
            bad('BUWidgets: kalin/ince yazi agirligi .%s (yalniz regular)' % w)
    (ok if 'systemName' not in all_swift else bad)('BUWidgets: SF Symbols (systemName) kullanilmamis (Lucide)')
    (ok if 'AppIntent' not in all_swift and 'Button(' not in all_swift else bad)('BUWidgets: interaktif widget/AppIntents yok')
    (ok if not re.search(r'URLSession|URLRequest|Data\(contentsOf', all_swift) else bad)('BUWidgets: ag istegi yok')
    keys = set(re.findall(r'"(widget\.[a-z]+\.(?:name|desc))"', all_swift)) | {'signedout.title', 'signedout.sub'}
    for lang in LANGS:
        p = os.path.join(WIDGETS, '%s.lproj' % lang, 'Localizable.strings')
        if not os.path.isfile(p):
            bad('BUWidgets %s.lproj/Localizable.strings yok' % lang)
            continue
        if read(p).startswith('﻿'):
            bad('%s Localizable.strings BOM' % lang)
        miss = sorted(keys - set(parse_strings(p)))
        if miss:
            bad('%s Localizable.strings eksik: %s' % (lang, miss))
        else:
            ok('BUWidgets %s Localizable.strings: %d anahtar tam' % (lang, len(keys)))


# Swift modelleri -> ornek JSON'larin Codable ile ayrisabilirligi (tum alanlar opsiyonel; TIP uyusmazligi = ayristirma hatasi)
SLUG_MODEL = {'menu': 'BuMenuSnap', 'timetable': 'BuTimetableSnap', 'events': 'BuEventsSnap',
              'announcements': 'BuAnnouncementsSnap', 'poll': 'BuPollSnap', 'quickaccess': 'BuQuickSnap',
              'social': 'BuSocialSnap'}


def swift_models():
    src = read(os.path.join(WIDGETS, 'BuWidgetModels.swift'))
    models = {}
    for m in re.finditer(r'struct (Bu\w+): (?:Decodable|BuSnapshot)\s*\{(.*?)\n\}', src, re.S):
        fields = {}
        for f in re.finditer(r'^    let (\w+): ([^\n]+)$', m.group(2), re.M):
            fields[f.group(1)] = f.group(2).strip()
        models[m.group(1)] = fields
    return models


def type_ok(v, t, models, path, errs):
    opt = t.endswith('?')
    base = t[:-1] if opt else t
    if v is None:
        if not opt:
            errs.append('%s: null ama tip %s' % (path, t))
        return
    if base == 'String':
        if not isinstance(v, str):
            errs.append('%s: String bekleniyordu, %r' % (path, v))
    elif base == 'Int':
        if isinstance(v, bool) or not isinstance(v, int):
            errs.append('%s: Int bekleniyordu, %r' % (path, v))
    elif base == 'Bool':
        if not isinstance(v, bool):
            errs.append('%s: Bool bekleniyordu, %r' % (path, v))
    elif base == '[String: String]':
        if not isinstance(v, dict) or not all(isinstance(x, str) for x in v.values()):
            errs.append('%s: [String:String] bekleniyordu' % path)
    elif base.startswith('[') and base.endswith(']'):
        if not isinstance(v, list):
            errs.append('%s: dizi bekleniyordu' % path)
            return
        for i, x in enumerate(v):
            type_ok(x, base[1:-1], models, '%s[%d]' % (path, i), errs)
    elif base in models:
        if not isinstance(v, dict):
            errs.append('%s: nesne bekleniyordu' % path)
            return
        for k, ft in models[base].items():
            if k in v:
                type_ok(v[k], ft, models, '%s.%s' % (path, k), errs)
    else:
        errs.append('%s: bilinmeyen tip %s' % (path, t))


def check_widget_samples():
    models = swift_models()
    needed = set(SLUG_MODEL.values()) | {'BuMeta'}
    if not needed <= set(models):
        bad('BuWidgetModels.swift modelleri ayrisamadi: eksik %s' % sorted(needed - set(models)))
        return
    total = 0
    errs = []
    for lang in LANGS:
        files = [(os.path.join(EXAMPLES, lang, '%s.json' % s), SLUG_MODEL[s]) for s in SLUG_MODEL]
        files += [(os.path.join(EXAMPLES, lang, 'meta.json'), 'BuMeta'),
                  (os.path.join(EXAMPLES, lang, 'meta-signed-out.json'), 'BuMeta')]
        if lang == 'tr':
            for s in ('menu', 'events', 'announcements', 'poll'):
                files.append((os.path.join(EXAMPLES, 'tr', 'empty', '%s.json' % s), SLUG_MODEL[s]))
            files.append((os.path.join(EXAMPLES, 'tr', 'signed-out', 'menu.json'), SLUG_MODEL['menu']))
        for fp, model in files:
            if not os.path.isfile(fp):
                continue
            with open(fp, 'r', encoding='utf-8') as f:
                data = json.load(f)
            total += 1
            type_ok(data, model, models, os.path.relpath(fp, EXAMPLES), errs)
    for model in SLUG_MODEL.values():
        for k in ('schema', 'state', 'expiresAt', 'lang', 'rtl', 'deepLink', 'a11y', 'strings'):
            if k not in models[model]:
                errs.append('%s: ortak zarf alani %s modelde yok' % (model, k))
    if errs:
        bad('ornek JSON ayristirma: %s' % errs[:5])
    else:
        ok("Swift modelleri %d ornek JSON'u (tr/en/ar + bos/oturumsuz) tip uyumsuzlugu olmadan ayristirir" % total)
    sample = read(os.path.join(WIDGETS, 'BuSampleData.swift'))
    for slug in list(SLUG_MODEL) + ['meta']:
        with open(os.path.join(EXAMPLES, 'tr', '%s.json' % slug), 'r', encoding='utf-8') as f:
            mini = json.dumps(json.load(f), ensure_ascii=False, separators=(',', ':'))
        (ok if mini in sample else bad)('BuSampleData.%s == examples/tr/%s.json' % (slug, slug))


def check_widget_ci():
    cm = read(os.path.join(ROOT, 'codemagic.yaml'))
    (ok if 'bu_widgets' in cm else bad)('codemagic.yaml: ios_signing icinde bu_widgets profili')
    eo = read(os.path.join(IOS, 'ExportOptions.plist'))
    (ok if WIDGET_BUNDLE in eo else bad)('ExportOptions.plist: %s' % WIDGET_BUNDLE)
    bi = read(os.path.join(ROOT, 'scripts', 'ios', 'build-ipa.sh'))
    (ok if 'BUWidgets' in bi and APP_GROUP in bi else bad)('build-ipa.sh: BUWidgets/App Group denetimi')
    doc = read(os.path.join(ROOT, 'docs', 'IOS_RELEASE.md'))
    (ok if 'Widget uzantısı için bugün yapılacaklar' in doc else bad)('docs/IOS_RELEASE.md: widget uzantisi bolumu')


CANONICAL_BUNDLE = 'tr.com.bukampus.app'  # kullanici karari 2026-10-31 (Android applicationId ile ayni)


def check_bundle_consistency(bundle):
    """Bundle id tek kaynakta tutarli mi: pbxproj, fastlane Appfile, codemagic.yaml; eski id hicbir yerde kalmamali."""
    (ok if bundle == CANONICAL_BUNDLE else bad)(f'Bundle id {bundle} == {CANONICAL_BUNDLE}')
    rels = ['mobile/ios/fastlane/Appfile', 'codemagic.yaml', 'mobile/ios/Runner.xcodeproj/project.pbxproj',
            '.github/workflows/ios-release.yml', 'mobile/ios/fastlane/Fastfile']
    old = 'edu.bingol.' + 'buKampus'
    for rel in rels:
        p = os.path.join(ROOT, rel)
        if os.path.isfile(p) and old in read(p):
            bad(f'{rel}: eski bundle id ({old}) kalmis')
    for rel, needle in (('mobile/ios/fastlane/Appfile', 'app_identifier("%s")' % bundle),
                        ('codemagic.yaml', 'BUNDLE_ID: "%s"' % bundle)):
        p = os.path.join(ROOT, rel)
        if os.path.isfile(p):
            (ok if needle in read(p) else bad)(f'{rel}: bundle id {bundle}' + ('' if needle in read(p) else ' ile UYUSMUYOR'))


def check_ci_files():
    try:
        import yaml  # type: ignore
    except Exception:
        warn('PyYAML yok: YAML sozdizimi atlandi (alternatif: node scripts/check-workflows.js)')
        return
    for rel in ('.github/workflows/ios-release.yml', 'codemagic.yaml'):
        p = os.path.join(ROOT, rel)
        if not os.path.isfile(p):
            warn(f'{rel} yok')
            continue
        try:
            yaml.safe_load(read(p))
            ok(f'{rel}: YAML gecerli')
        except Exception as e:  # noqa: BLE001
            bad(f'{rel}: YAML hatasi {e}')


def main():
    print('== iOS dosya duzeyi kontrol ==')
    info = check_info_plist()
    check_strings(info)
    check_entitlements()
    check_push_categories()
    check_privacy()
    bundle = check_pbxproj()
    check_icons()
    check_google_plist(bundle)
    check_bundle_consistency(bundle)
    check_ci_files()
    check_widget_pbx()
    check_widget_files()
    check_widget_samples()
    check_widget_ci()
    print(f'\nOzet: {len(errors)} hata, {len(warnings)} uyari')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
