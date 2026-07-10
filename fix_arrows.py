import os
import re

def fix_arrows_in_dir(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                if 'Icons.arrow_back_ios_new_rounded' in content:
                    # First remove const from Icon(Icons.arrow_back_ios_new_rounded...)
                    content = re.sub(r'const\s+Icon\(\s*Icons\.arrow_back_ios_new_rounded', 'Icon(Icons.arrow_back_ios_new_rounded', content)
                    
                    # Then replace the icon
                    content = content.replace(
                        'Icons.arrow_back_ios_new_rounded', 
                        '(Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded)'
                    )
                    
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed {file_path}")

fix_arrows_in_dir('lib')
