#!/usr/bin/env python3
"""Print Runner's bundle ID, excluding test and notification extension targets."""
import pathlib
import re
import sys


def runner_bundle_id(project):
    settings = re.findall(r'buildSettings\s*=\s*\{([^{}]*)\}', project, re.S)
    runner = [block for block in settings if re.search(
        r'\bINFOPLIST_FILE\s*=\s*"?Runner/Info\.plist"?\s*;', block)]
    ids = [re.search(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([A-Za-z0-9.\-]+)"?\s*;', block)
           for block in runner]
    if len(runner) != 3 or not all(ids) or len({m.group(1) for m in ids}) != 1:
        raise ValueError('Runner Debug/Release/Profile bundle IDs must exist and match')
    return ids[0].group(1)


if __name__ == '__main__':
    root = pathlib.Path(__file__).resolve().parents[2]
    project = root / 'mobile/ios/Runner.xcodeproj/project.pbxproj'
    try:
        print(runner_bundle_id(project.read_text(encoding='utf-8')))
    except ValueError as error:
        sys.exit(str(error))
