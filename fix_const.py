import os
import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace `const Text('...'.tr()` with `Text('...'.tr()`
    content = re.sub(r"const\s+Text\(([^)]*\.tr\(\)[^)]*)\)", r"Text(\1)", content)

    # Sometimes it might be multiline:
    # const Text(
    #   'pair_device'.tr(),
    content = re.sub(r"const\s+Text\(\s*['\"][a-zA-Z0-9_]+['\"]\s*\.tr\(\)", lambda m: m.group(0).replace("const ", ""), content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

fix_file('lib/screens/device/pair_device_screen.dart')
fix_file('lib/screens/device/pair_device2_screen.dart')

print("Consts fixed!")
