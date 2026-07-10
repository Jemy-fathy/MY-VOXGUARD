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
    "signup_confirmed": "Sign Up confirmed",
    "add_emergency_info": "Add Emergency information",
    "skip_for_now": "skip for now"
}

ar_keys = {
    "signup_confirmed": "تم تأكيد إنشاء الحساب",
    "add_emergency_info": "إضافة معلومات الطوارئ",
    "skip_for_now": "تخطي الآن"
}

update_json('assets/translations/en.json', en_keys)
update_json('assets/translations/ar.json', ar_keys)

file_path = 'lib/screens/auth/confirmed_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:easy_localization/easy_localization.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:easy_localization/easy_localization.dart';")

content = content.replace('Alignment.centerLeft', 'AlignmentDirectional.centerStart')
content = content.replace('Icons.arrow_back', 'Icons.arrow_back_ios_new_rounded')

content = content.replace('const Text(\n                        "Sign Up confirmed",', 'Text(\n                        "signup_confirmed".tr(),')
content = content.replace('text: "Add Emergency information",', 'text: "add_emergency_info".tr(),')
content = content.replace('const Text(\n                          "skip for now",', 'Text(\n                          "skip_for_now".tr(),')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed confirmed_screen.dart and translations!")
