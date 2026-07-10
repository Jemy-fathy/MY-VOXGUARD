import os

def fix_ltr2_in_dir(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                changed = False

                search_str = "Transform.flip(flipX: context.locale.languageCode == 'ar', child: "
                if search_str in content:
                    # Manually replace the Transform.flip and the corresponding closing parenthesis
                    
                    # Split by the search_str
                    parts = content.split(search_str)
                    new_content = parts[0]
                    
                    for i in range(1, len(parts)):
                        part = parts[i]
                        
                        # We need to find the matching closing parenthesis for Transform.flip(
                        # But wait, we just stripped "Transform.flip(... child: ". 
                        # So `part` starts with "Icon(".
                        # We need to find the matching closing parenthesis for Icon(...), and then remove the ONE parenthesis after it!
                        
                        paren_count = 0
                        icon_end_idx = -1
                        for j, char in enumerate(part):
                            if char == '(':
                                paren_count += 1
                            elif char == ')':
                                paren_count -= 1
                                if paren_count == 0:
                                    icon_end_idx = j
                                    break
                                    
                        if icon_end_idx != -1:
                            # We found the end of the Icon(...)
                            # Now we need to remove the VERY NEXT closing parenthesis which belongs to Transform.flip
                            # It might be immediately after, or after some whitespace.
                            
                            rest = part[icon_end_idx+1:]
                            # find first ')' and remove it
                            paren_idx = rest.find(')')
                            if paren_idx != -1:
                                new_rest = rest[:paren_idx] + rest[paren_idx+1:]
                                new_content += part[:icon_end_idx+1] + new_rest
                            else:
                                new_content += part # fallback
                        else:
                            new_content += part # fallback

                    content = new_content
                    changed = True

                if "AlignmentDirectional.centerStart" in content:
                    content = content.replace("AlignmentDirectional.centerStart", "Alignment.centerLeft")
                    changed = True

                if changed:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed {file_path}")

fix_ltr2_in_dir('lib')
