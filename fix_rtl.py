import os
import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Fix Column crossAxisAlignment
    content = re.sub(r"crossAxisAlignment:\s*isArabic\s*\?\s*CrossAxisAlignment\.end\s*:\s*CrossAxisAlignment\.start", "crossAxisAlignment: CrossAxisAlignment.start", content)
    content = re.sub(r"crossAxisAlignment:\s*context\.locale\.languageCode\s*==\s*['\"]ar['\"]\s*\?\s*CrossAxisAlignment\.end\s*:\s*CrossAxisAlignment\.start", "crossAxisAlignment: CrossAxisAlignment.start", content)

    # Fix Align alignment
    content = re.sub(r"alignment:\s*isArabic\s*\?\s*Alignment\.centerRight\s*:\s*Alignment\.centerLeft", "alignment: AlignmentDirectional.centerStart", content)
    content = re.sub(r"alignment:\s*context\.locale\.languageCode\s*==\s*['\"]ar['\"]\s*\?\s*Alignment\.centerRight\s*:\s*Alignment\.centerLeft", "alignment: AlignmentDirectional.centerStart", content)
    
    # Fix TextAlign
    content = re.sub(r"textAlign:\s*isArabic\s*\?\s*TextAlign\.right\s*:\s*TextAlign\.left", "textAlign: TextAlign.start", content)
    content = re.sub(r"textAlign:\s*context\.locale\.languageCode\s*==\s*['\"]ar['\"]\s*\?\s*TextAlign\.right\s*:\s*TextAlign\.left", "textAlign: TextAlign.start", content)

    with open(filepath, 'w') as f:
        f.write(content)

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print("RTL alignments fixed!")
