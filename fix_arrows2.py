import os

def fix_arrows2_in_dir(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                if 'Directionality.of(context) == TextDirection.rtl' in content:
                    content = content.replace(
                        'Directionality.of(context) == TextDirection.rtl', 
                        "Localizations.localeOf(context).languageCode == 'ar'"
                    )
                    
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed {file_path}")

fix_arrows2_in_dir('lib')
