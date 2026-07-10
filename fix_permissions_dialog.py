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
    "dialog_permission_desc": "Allow VoxGuard to access your Location, Microphone, Bluetooth, and Motion Activity?",
    "allow": "Allow",
    "dont_allow": "Don't Allow"
}

ar_keys = {
    "dialog_permission_desc": "هل تسمح لتطبيق VoxGuard بالوصول إلى الموقع، الميكروفون، البلوتوث ونشاط الحركة؟",
    "allow": "سماح",
    "dont_allow": "عدم السماح"
}

update_json('assets/translations/en.json', en_keys)
update_json('assets/translations/ar.json', ar_keys)

file_path = 'lib/screens/auth/permissions_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('const Text("Allow VoxGuard to access your Location, Microphone, Bluetooth, and Motion Activity?")', 'Text("dialog_permission_desc".tr())')
content = content.replace('const Text("Don\'t Allow", style: TextStyle(color: Colors.grey))', 'Text("dont_allow".tr(), style: const TextStyle(color: Colors.grey))')
content = content.replace('const Text("Allow", style: TextStyle(color: Color(0xFFCB30E0), fontWeight: FontWeight.bold))', 'Text("allow".tr(), style: const TextStyle(color: Color(0xFFCB30E0), fontWeight: FontWeight.bold))')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated permissions dialog and translations!")
