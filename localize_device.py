import json
import os

def update_json(file_path, new_keys):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    for k, v in new_keys.items():
        if k not in data:
            data[k] = v
            
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

en_keys = {
    "pair_device": "Pair Device",
    "scanning_stopped": "Scanning stopped",
    "scanning_for_devices": "Scanning for devices...",
    "available_devices": "Available devices",
    "searching": "Searching...",
    "no_devices_found": "No devices found",
    "ready_to_pair": "Ready to pair",
    "connect": "Connect",
    "connected": "Connected",
    "show_monitoring": "Show monitoring"
}

ar_keys = {
    "pair_device": "ربط جهاز",
    "scanning_stopped": "توقف البحث",
    "scanning_for_devices": "جاري البحث عن أجهزة...",
    "available_devices": "الأجهزة المتاحة",
    "searching": "جاري البحث...",
    "no_devices_found": "لم يتم العثور على أجهزة",
    "ready_to_pair": "جاهز للربط",
    "connect": "اتصال",
    "connected": "متصل",
    "show_monitoring": "عرض المراقبة"
}

update_json('assets/translations/en.json', en_keys)
update_json('assets/translations/ar.json', ar_keys)

# Now update the dart files
import re

def add_import_and_replace(file_path, replacements):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if "import 'package:easy_localization/easy_localization.dart';" not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:easy_localization/easy_localization.dart';")
        
    for old, new in replacements.items():
        content = content.replace(old, new)
        
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

replacements_1 = {
    "'Pair Device'": "'pair_device'.tr()",
    "'Scanning stopped'": "'scanning_stopped'.tr()",
    "'Scanning for devices...'": "'scanning_for_devices'.tr()",
    "'Available devices'": "'available_devices'.tr()",
    "'Searching...'": "'searching'.tr()",
    "'No devices found'": "'no_devices_found'.tr()",
    "'Ready to pair'": "'ready_to_pair'.tr()",
    "'Connect'": "'connect'.tr()"
}

replacements_2 = {
    "'Pair Device '": "'pair_device'.tr()",
    "'Scanning for devices'": "'scanning_for_devices'.tr()",
    "'Available device'": "'available_devices'.tr()",
    "'Connected'": "'connected'.tr()",
    "'ready to pair'": "'ready_to_pair'.tr()",
    "'Connect'": "'connect'.tr()",
    "'Show monitoring'": "'show_monitoring'.tr()"
}

add_import_and_replace('lib/screens/device/pair_device_screen.dart', replacements_1)
add_import_and_replace('lib/screens/device/pair_device2_screen.dart', replacements_2)

print("Localization added successfully!")
