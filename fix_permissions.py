import json

def update_json(file_path, new_keys):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    for k, v in new_keys.items():
        if k not in data:
            data[k] = v
            
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

en_keys = {
    "grant_permissions_error": "Please grant essential permissions to continue",
    "enable_safety_net": "Enable your safety net",
    "location_access": "Location Access",
    "location_access_desc": "Used for sharing your real-time location with emergency contacts.",
    "mic_access": "Microphone Access",
    "mic_access_desc": "Used for recording audio evidence when a threat is detected.",
    "bluetooth_access": "Bluetooth Access",
    "bluetooth_access_desc": "Used to connect to safety accessories or detect nearby devices.",
    "motion_activity": "Motion Activity",
    "motion_activity_desc": "Used for detecting falls, sudden movements, or distress signals.",
    "grant_permissions": "Grant permissions"
}

ar_keys = {
    "grant_permissions_error": "يرجى منح الصلاحيات الأساسية للمتابعة",
    "enable_safety_net": "تفعيل شبكة الأمان الخاصة بك",
    "location_access": "صلاحية الموقع",
    "location_access_desc": "تُستخدم لمشاركة موقعك المباشر مع جهات اتصال الطوارئ.",
    "mic_access": "صلاحية الميكروفون",
    "mic_access_desc": "تُستخدم لتسجيل أدلة صوتية عند اكتشاف أي خطر.",
    "bluetooth_access": "صلاحية البلوتوث",
    "bluetooth_access_desc": "تُستخدم للاتصال بملحقات الأمان أو اكتشاف الأجهزة القريبة.",
    "motion_activity": "نشاط الحركة",
    "motion_activity_desc": "تُستخدم لاكتشاف السقوط، الحركات المفاجئة، أو إشارات الاستغاثة.",
    "grant_permissions": "منح الصلاحيات"
}

update_json('assets/translations/en.json', en_keys)
update_json('assets/translations/ar.json', ar_keys)

file_path = 'lib/screens/auth/permissions_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:easy_localization/easy_localization.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:easy_localization/easy_localization.dart';")

content = content.replace('const Text("Please grant essential permissions to continue")', 'Text("grant_permissions_error".tr())')
content = content.replace('const Text(\n                  "Enable your safety net"', 'Text(\n                  "enable_safety_net".tr()')
content = content.replace('children: const [', 'children: [')
content = content.replace('title: "Location Access", \n                      description: "Used for sharing your real-time location with emergency contacts."', 'title: "location_access".tr(), \n                      description: "location_access_desc".tr()')
content = content.replace('title: "Microphone Access", \n                      description: "Used for recording audio evidence when a threat is detected."', 'title: "mic_access".tr(), \n                      description: "mic_access_desc".tr()')
content = content.replace('title: "Bluetooth Access", \n                      description: "Used to connect to safety accessories or detect nearby devices."', 'title: "bluetooth_access".tr(), \n                      description: "bluetooth_access_desc".tr()')
content = content.replace('title: "Motion Activity", \n                      description: "Used for detecting falls, sudden movements, or distress signals."', 'title: "motion_activity".tr(), \n                      description: "motion_activity_desc".tr()')
content = content.replace('text: "Grant permissions"', 'text: "grant_permissions".tr()')
content = content.replace('const Text("Skip for now"', 'Text("skip_for_now".tr()')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated permissions_screen.dart and translations!")
