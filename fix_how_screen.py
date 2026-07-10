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
    "how_we_keep_safe": "How we keep you safe ?",
    "sos_alert": "SOS Alert",
    "sos_alert_desc": "Instantly send an emergency alert to your trusted contacts with your location.",
    "voice_password_alert_desc": "Activate alerts hands-free by speaking your secret phrase, even from a distance.",
    "fake_call_desc": "Discreetly simulate an incoming phone call to create a diversion and exit unsafe situations.",
    "trip_tracking": "Trip Tracking",
    "trip_tracking_desc": "Share your live journey with friends or family so they know you've arrived safely.",
    "continue": "Continue"
}

ar_keys = {
    "how_we_keep_safe": "كيف نحافظ على سلامتك؟",
    "sos_alert": "استغاثة SOS",
    "sos_alert_desc": "أرسل تنبيه طوارئ فوراً لجهات اتصالك الموثوقة مع موقعك الحالي.",
    "voice_password_alert_desc": "فعل التنبيهات بصوتك باستخدام عبارتك السرية، حتى من مسافة بعيدة.",
    "fake_call_desc": "قم بمحاكاة مكالمة واردة بشكل سري للتهرب من المواقف غير الآمنة.",
    "trip_tracking": "تتبع الرحلة",
    "trip_tracking_desc": "شارك رحلتك المباشرة مع أصدقائك أو عائلتك ليعرفوا أنك وصلت بأمان.",
    "continue": "متابعة"
}

update_json('assets/translations/en.json', en_keys)
update_json('assets/translations/ar.json', ar_keys)

file_path = 'lib/screens/auth/how_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:easy_localization/easy_localization.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:easy_localization/easy_localization.dart';")

content = content.replace('const Text(\n                  "How we keep you safe ?"', 'Text(\n                  "how_we_keep_safe".tr()')
content = content.replace('children: const [', 'children: [')
content = content.replace('title: "SOS Alert", \n                      description: "Instantly send an emergency alert to your trusted contactes with your location."', 'title: "sos_alert".tr(), \n                      description: "sos_alert_desc".tr()')
content = content.replace('title: "Voice Password", \n                      description: "Activate alerts hands-free by speaking your secret phrase, even from a distance."', 'title: "voice_password".tr(), \n                      description: "voice_password_alert_desc".tr()')
content = content.replace('title: "Fake Call", \n                      description: "Discreetly simulate an incoming phone call to create a diversion and exit unsafe situations."', 'title: "fake_call".tr(), \n                      description: "fake_call_desc".tr()')
content = content.replace('title: "Trip Tracking", \n                      description: "Share your live journey with friends or family so they know you\'ve arrived safely."', 'title: "trip_tracking".tr(), \n                      description: "trip_tracking_desc".tr()')
content = content.replace('text: "Continue"', 'text: "continue".tr()')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated how_screen.dart and translations!")
