import os
import re

def fix_arrows5_in_dir(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                target_str = "(Directionality.of(context).index == 0 ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded)"
                if target_str in content:
                    # Replace Icon(...) with Transform.flip(..., child: Icon(...))
                    # We use regex to capture whatever properties are inside the Icon widget (like color, size)
                    
                    pattern = r"Icon\(\s*\(\s*Directionality\.of\(context\)\.index == 0 \? Icons\.arrow_forward_ios_rounded : Icons\.arrow_back_ios_new_rounded\s*\)(.*?)\)"
                    
                    def replacement(match):
                        props = match.group(1)
                        return f"Transform.flip(flipX: Directionality.of(context).index == 0, child: Icon(Icons.arrow_back_ios_new_rounded{props}))"
                    
                    new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)
                    
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Fixed {file_path}")

fix_arrows5_in_dir('lib')
