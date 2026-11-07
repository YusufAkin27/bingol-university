#!/usr/bin/env python3
"""iOS dosya duzeyi on kontrol (macOS/Xcode GEREKTIRMEZ; Windows'ta da calisir).

Kullanim (repo kokunden):  python -I -X utf8 scripts/ios/check-ios-static.py
Cikis kodu: 0 = tum kontroller gecti (uyarilar olabilir), 1 = en az bir HATA.

Bu betik Xcode'un yerine GECMEZ: yalnizca plist/pbxproj/varlik tutarliligini ve App Store'un en sik
reddettigi dosya duzeyi hatalari yakalar. Derleme/imza/yukleme macOS'ta dogrulanir (docs/IOS_RELEASE.md).
"""
import glob
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
]
# Uygulamada KARSILIGI OLMAYAN izin anahtarlari: eklenirse App Review "kullanilmayan izin" sorar
FORBIDDEN_USAGE = [
    'NSLocationWhenInUseUsageDescription', 'NSLocationAlwaysAndWhenInUseUsageDescription',
    'NSLocationAlwaysUsageDescription', 'NSUserTrackingUsageDescription', 'NSBluetoothAlwaysUsageDescription',
    'NSCalendarsUsageDescription', 'NSRemindersUsageDescription', 'NSSpeechRecognitionUsageDescription',
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
    x = read(os.path.join(IOS, 'Flutter', 'BuPush.xcconfig.example'))
    if 'RunnerRelease.entitlements' in x and 'config=Release' in x:
        ok('BuPush.xcconfig.example: Release -> RunnerRelease.entitlements (production)')
    else:
        bad('BuPush.xcconfig.example Release icin RunnerRelease.entitlements baglamali')


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
    ids = set(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9.\-]+);', s)) - {
        i for i in re.findall(r'PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9.\-]+);', s) if i.endswith('.RunnerTests')}
    if len(ids) == 1:
        ok('Bundle id (tek deger): ' + next(iter(ids)))
    else:
        bad(f'Runner hedefinde birden fazla bundle id: {sorted(ids)}')
    if 'Debug.xcconfig' in s and 'Release.xcconfig' in s:
        ok('Debug/Release xcconfig baglantili')
    # dosya var mi
    for name in ('BuNativeBridge.swift', 'PrivacyInfo.xcprivacy', 'AppDelegate.swift', 'SceneDelegate.swift'):
        (ok if os.path.isfile(os.path.join(RUNNER, name)) else bad)(f'Runner/{name} diskte')
    return next(iter(ids)) if len(ids) == 1 else None


def png_size_alpha(path):
    with open(path, 'rb') as f:
        d = f.read(64)
    w, h, _bd, ct = struct.unpack('>IIBB', d[16:26])
    return w, h, ct in (4, 6)


def check_icons():
    base = os.path.join(RUNNER, 'Assets.xcassets', 'AppIcon.appiconset')
    mk = os.path.join(base, 'Icon-App-1024x1024@1x.png')
    w, h, alpha = png_size_alpha(mk)
    if (w, h) != (1024, 1024):
        bad(f'App Store simgesi 1024x1024 olmali ({w}x{h})')
    elif alpha:
        bad('App Store simgesi (1024) ALFA kanali iceriyor: App Store Connect reddeder')
    else:
        ok('AppIcon 1024x1024, alfasiz')
    bad_alpha = [os.path.basename(p) for p in glob.glob(os.path.join(base, '*.png')) if png_size_alpha(p)[2]]
    (ok if not bad_alpha else bad)('Diger AppIcon boyutlari alfasiz' if not bad_alpha else f'Alfali simgeler: {bad_alpha}')
    ls = os.path.join(RUNNER, 'Base.lproj', 'LaunchScreen.storyboard')
    t = read(ls)
    if 'red="0.7765" green="0.1647" blue="0.1255"' in t:
        ok('LaunchScreen: marka zemini #C62A20 (Android splash_bg ile ayni)')
    else:
        warn('LaunchScreen zemin rengi #C62A20 degil')


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
                        ('codemagic.yaml', 'bundle_identifier: %s' % bundle)):
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
    check_privacy()
    bundle = check_pbxproj()
    check_icons()
    check_google_plist(bundle)
    check_bundle_consistency(bundle)
    check_ci_files()
    print(f'\nOzet: {len(errors)} hata, {len(warnings)} uyari')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
