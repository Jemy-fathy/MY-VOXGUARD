import os

def fix_arrows3_in_dir(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                if "Localizations.localeOf(context).languageCode == 'ar'" in content:
                    content = content.replace(
                        "Localizations.localeOf(context).languageCode == 'ar'", 
                        "context.locale.languageCode == 'ar'"
                    )
                    
                    if "import 'package:easy_localization/easy_localization.dart';" not in content:
                        content = "import 'package:easy_localization/easy_localization.dart';\n" + content
                    
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed {file_path}")

fix_arrows3_in_dir('lib')
