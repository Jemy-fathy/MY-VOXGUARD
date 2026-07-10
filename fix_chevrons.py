import os
import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Replace context.locale.languageCode == 'ar' ? Icons.chevron_right : Icons.chevron_left
    content = re.sub(r"context\.locale\.languageCode\s*==\s*['\"]ar['\"]\s*\?\s*Icons\.chevron_right\s*:\s*Icons\.chevron_left", "Icons.arrow_back_ios_new_rounded", content)
    
    # Just in case isArabic was used
    content = re.sub(r"isArabic\s*\?\s*Icons\.chevron_right\s*:\s*Icons\.chevron_left", "Icons.arrow_back_ios_new_rounded", content)

    with open(filepath, 'w') as f:
        f.write(content)

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print("Chevrons fixed!")
