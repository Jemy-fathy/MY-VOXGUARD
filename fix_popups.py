import os

files = [
    "lib/screens/fake_call/incoming_fake_call_police.dart",
    "lib/screens/fake_call/incoming_fake_call_mom.dart",
    "lib/screens/fake_call/incoming_fake_call_dad.dart"
]

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Replace showModalBottomSheet with showDialog and alignment
    old_sheet = """    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),"""

    new_sheet = """    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 160),"""

    content = content.replace(old_sheet, new_sheet)

    # Need to close the Material and Align in both methods
    old_end = """              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );"""

    new_end = """              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  },
);"""
    
    # Simple replace might fail if formatting is slightly off, let's just do a regex or string replacement carefully
    
    # Actually, let's just replace the exact end of the block
    content = content.replace(old_end, new_end)

    with open(file, 'w') as f:
        f.write(content)

print("Done")
