import json
import os
import re

def update_json(file_path, new_keys):
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    for k, v in new_keys.items():
        if k not in data:
            data[k] = v
            
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

en_keys = {
    "emergency_info_desc": "This information will only be shared with your trusted contacts in an emergency.",
    "peanuts_penicillin_hint": "Peanuts, Penicillin",
    "asthma_diabetes_hint": "Asthma, Diabetes",
    "save": "Save"
}

ar_keys = {
    "emergency_info_desc": "ستتم مشاركة هذه المعلومات فقط مع جهات الاتصال الموثوقة في حالة الطوارئ.",
    "peanuts_penicillin_hint": "الفول السوداني، البنسلين",
    "asthma_diabetes_hint": "الربو، السكري",
    "save": "حفظ"
}

update_json('assets/translations/en.json', en_keys)
update_json('assets/translations/ar.json', ar_keys)

file_path = 'lib/screens/auth/emergency_information_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:easy_localization/easy_localization.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:easy_localization/easy_localization.dart';")

# Fix Icon
content = content.replace('Icons.arrow_back', 'Icons.arrow_back_ios_new_rounded')

# Replace texts
content = content.replace("'Emergency information'", "'emergency_info'.tr()")
content = content.replace("'This information will only be shared with your trusted contacts in an emergency.'", "'emergency_info_desc'.tr()")
content = content.replace("'Blood Type'", "'blood_type'.tr()")
content = content.replace("' O positive'", "'o_positive'.tr()")
content = content.replace("'Allergies'", "'allergies'.tr()")
content = content.replace("' Peanuts, Penicillin'", "'peanuts_penicillin_hint'.tr()")
content = content.replace("'Medical conditions'", "'medical_conditions'.tr()")
content = content.replace("' Asthma, Diabetes'", "'asthma_diabetes_hint'.tr()")
content = content.replace("text: 'Save'", "text: 'save'.tr()")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed emergency_information_screen.dart and translations!")
