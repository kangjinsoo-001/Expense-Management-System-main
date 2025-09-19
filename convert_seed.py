#!/usr/bin/env python3

# Read the file
with open('db/seeds/25_request_templates_with_fields.rb', 'r') as f:
    content = f.read()

# Replace fields_temp: with fields: and add is_required: true
lines = content.split('\n')
new_lines = []
for i, line in enumerate(lines):
    if 'fields_temp:' in line:
        new_lines.append(line.replace('fields_temp:', 'fields:'))
    elif 'fields_temp2:' in line:
        # Skip this line, we'll merge the fields
        continue
    elif 'field_key:' in line and i > 0:
        # Check if this is in fields_temp section
        in_required = False
        for j in range(i-1, max(0, i-10), -1):
            if 'fields_temp:' in lines[j]:
                in_required = True
                break
            elif 'fields_temp2:' in lines[j]:
                in_required = False
                break
        
        # Add is_required field
        if '}' in line:
            if in_required:
                new_lines.append(line.replace('}', ', is_required: true }'))
            else:
                new_lines.append(line.replace('}', ', is_required: false }'))
        else:
            new_lines.append(line)
    else:
        new_lines.append(line)

# Merge fields_temp and fields_temp2 into fields
output = []
i = 0
while i < len(new_lines):
    if 'fields:' in new_lines[i]:
        # Start of fields array
        output.append(new_lines[i])
        i += 1
        # Collect all fields until we reach the end
        fields = []
        bracket_count = 1
        while i < len(new_lines) and bracket_count > 0:
            if '[' in new_lines[i]:
                bracket_count += 1
            if ']' in new_lines[i]:
                bracket_count -= 1
                if bracket_count == 0:
                    # Check if next section is fields_temp2
                    j = i + 1
                    while j < len(new_lines) and new_lines[j].strip() == '':
                        j += 1
                    if j < len(new_lines) and 'fields_temp2:' not in lines[j-1]:
                        output.append(new_lines[i])
                        break
                    # Skip the closing bracket and look for fields_temp2
                    i = j
                    continue
            output.append(new_lines[i])
            i += 1
    else:
        output.append(new_lines[i])
        i += 1

# Write back
content = '\n'.join(output)
content = content.replace('fields_temp:', 'fields:')
content = content.replace('fields_temp2:', 'fields:')

with open('db/seeds/25_request_templates_with_fields.rb', 'w') as f:
    f.write(content)