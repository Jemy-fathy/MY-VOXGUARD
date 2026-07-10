import os
import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Replace manual ternaries with just Icons.arrow_back_ios_new_rounded
    # Pattern: context.locale.languageCode == 'ar' ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios
    content = re.sub(r"context\.locale\.languageCode\s*==\s*['\"]ar['\"]\s*\?\s*Icons\.arrow_back_ios_new_rounded\s*:\s*Icons\.arrow_back_ios", "Icons.arrow_back_ios_new_rounded", content)
    
    # Pattern: context.locale.languageCode == 'ar' ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back
    content = re.sub(r"context\.locale\.languageCode\s*==\s*['\"]ar['\"]\s*\?\s*Icons\.arrow_back_ios_new_rounded\s*:\s*Icons\.arrow_back", "Icons.arrow_back_ios_new_rounded", content)

    # Pattern: isArabic ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back_ios
    content = re.sub(r"isArabic\s*\?\s*Icons\.arrow_back_ios_new_rounded\s*:\s*Icons\.arrow_back_ios", "Icons.arrow_back_ios_new_rounded", content)

    # Pattern: isArabic ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back
    content = re.sub(r"isArabic\s*\?\s*Icons\.arrow_back_ios_new_rounded\s*:\s*Icons\.arrow_back", "Icons.arrow_back_ios_new_rounded", content)

    # Now replace any remaining naked Icons.arrow_back_ios that is NOT _new or _new_rounded
    # Be careful not to replace Icons.arrow_back_ios_new
    content = re.sub(r"Icons\.arrow_back_ios(?!_new)", "Icons.arrow_back_ios_new_rounded", content)

    # Replace Icons.arrow_back with Icons.arrow_back_ios_new_rounded for consistency? 
    # Maybe only if they are used as back buttons. Let's just leave naked Icons.arrow_back alone 
    # since it auto-mirrors anyway. The user said "any icon like this one" which means the iOS style one.

    # What about arrow_forward_ios? Let's check if there are ternaries for it
    # context.locale.languageCode == 'ar' ? Icons.arrow_back_ios : Icons.arrow_forward_ios
    content = re.sub(r"context\.locale\.languageCode\s*==\s*['\"]ar['\"]\s*\?\s*Icons\.arrow_back_ios_new_rounded\s*:\s*Icons\.arrow_forward_ios", "Icons.arrow_forward_ios", content)
    content = re.sub(r"context\.locale\.languageCode\s*==\s*['\"]ar['\"]\s*\?\s*Icons\.arrow_back_ios\s*:\s*Icons\.arrow_forward_ios", "Icons.arrow_forward_ios", content)

    with open(filepath, 'w') as f:
        f.write(content)

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print("Icons fixed!")
