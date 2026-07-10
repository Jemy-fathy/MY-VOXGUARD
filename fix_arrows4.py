import os

def fix_arrows4_in_dir(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                if "context.locale.languageCode == 'ar'" in content and "Icons.arrow_forward_ios_rounded" in content:
                    content = content.replace(
                        "context.locale.languageCode == 'ar' ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded", 
                        "Directionality.of(context).index == 0 ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded"
                    )
                    
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed {file_path}")

fix_arrows4_in_dir('lib')
