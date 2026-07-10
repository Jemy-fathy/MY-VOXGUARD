import os
import re

def fix_ltr_in_dir(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                changed = False

                # We want to replace:
                # Transform.flip(flipX: context.locale.languageCode == 'ar', child: Icon(...))
                # with just Icon(...)
                
                # Let's find "Transform.flip(flipX: context.locale.languageCode == 'ar', child: "
                # and replace it with nothing, then we have an extra ")" at the end.
                
                # A more robust regex:
                # Match Transform.flip( ... child: (Icon( ... )) )
                # Since Icon(...) can contain nested parentheses, regex is tricky.
                # But we know that the string starts with "Transform.flip(flipX: context.locale.languageCode == 'ar', child: "
                
                search_str = "Transform.flip(flipX: context.locale.languageCode == 'ar', child: Icon("
                if search_str in content:
                    # We will replace this prefix with "Icon("
                    content = content.replace(search_str, "Icon(")
                    # Now we have an extra closing parenthesis at the very end of this statement.
                    # Usually it's like: `icon: Transform.flip(..., child: Icon(...)),`
                    # which became `icon: Icon(...)),`
                    # We need to change `icon: Icon(...)),` to `icon: Icon(...),`
                    # So we find `)),` and change to `),` BUT ONLY where we did the replacement!
                    # Actually, a better approach is to use regex with balanced parenthesis if possible, 
                    # but since Dart formatting is predictable, let's just do it manually.
                    pass

                # Let's just use a simple string replace for the exact lines that exist in the files.
                # In most files it looks exactly like this:
                # Transform.flip(flipX: context.locale.languageCode == 'ar', child: Icon(Icons.arrow_back_ios_new_rounded,
                #   color: Colors.black87,
                # ))
                
                # Wait, I will just use a simpler regex that matches up to the first parenthesis of Icon, and then we just clean up the trailing parenthesis.
                # Or I can just write a quick dart script using analyzer? No, too complex.
                
                # Let's use re.sub with a carefully crafted regex
                pattern = r"Transform\.flip\(\s*flipX:\s*context\.locale\.languageCode == 'ar',\s*child:\s*(Icon\([^)]*\)?)\)"
                
                # The above regex assumes Icon(...) doesn't have deeply nested parens.
                # `Icons.arrow_back_ios_new_rounded` has no parens. `color: Colors.white` has no parens.
                # So `Icon([^)]*)` matches the whole Icon widget perfectly!
                # Wait, some icons have `Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 30)` - still no parens inside!
                # So `Icon\([^)]+\)` works!
                
                def replace_func(match):
                    return match.group(1)

                new_content, count = re.subn(pattern, replace_func, content)
                if count > 0:
                    content = new_content
                    changed = True

                # Handle the specific case in settings_screen.dart:
                # Transform.flip(flipX: context.locale.languageCode == 'ar', child: Icon(Icons.arrow_back_ios_new_rounded,
                #   color: Colors.white,
                #   size: 30,
                # ))
                pattern_multiline = r"Transform\.flip\(\s*flipX:\s*context\.locale\.languageCode == 'ar',\s*child:\s*(Icon\([^)]+\))\s*\)"
                new_content2, count2 = re.subn(pattern_multiline, replace_func, content, flags=re.DOTALL)
                if count2 > 0:
                    content = new_content2
                    changed = True

                if "AlignmentDirectional.centerStart" in content:
                    content = content.replace("AlignmentDirectional.centerStart", "Alignment.centerLeft")
                    changed = True
                    
                # In settings_screen.dart, the back button is in a Row.
                # We need to wrap that Row with Directionality(textDirection: TextDirection.ltr, child: Row(...))
                # Or simply add `textDirection: TextDirection.ltr` to the Row.
                if "settings_screen.dart" in file_path:
                    if "child: Row(" in content and "TextDirection.ltr" not in content:
                        content = content.replace("child: Row(", "child: Row(\n                    textDirection: TextDirection.ltr,")
                        changed = True

                if changed:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed {file_path}")

fix_ltr_in_dir('lib')
