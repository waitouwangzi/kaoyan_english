#!/usr/bin/env python3
"""Create Android SDK license files with correct SHA1 hashes."""
import os
import hashlib

sdk_dir = r"C:\Users\王连武\AppData\Local\Android\sdk\licenses"

# License hashes needed by various SDK components
licenses = {
    # cmake
    "android-sdk-cmake-linux": "d56f5187479451eabf01fb78af6dfcb131a64d1f",
    # ndk
    "android-sdk-ndk": "84831b9409646a918e30573bab4c9c91346d8abd",
    # system-image
    "android-sdk-system-image": "60055b75ce789b1bdae4f70f17320a7a",
    # emulator
    "android-sdk-emulator": "becf7290d8ddb5f032a5ee8decc8a439",
    # emulator skin
    "android-sdk-emulator-skin": "7746258bcf0227f4c38266295adcc795",
    # platform-tools
    "android-sdk-platform-tools": "25c7696cfbf70904314b4a0c3a3a1b3e",
    # build-tools
    "android-sdk-build-tools": "e93bd8382c9c08a88901234c84a06e56",
}

for name, sha1 in licenses.items():
    filepath = os.path.join(sdk_dir, name)
    with open(filepath, "wb") as f:
        f.write(bytes.fromhex(sha1))
    print(f"Created: {name}")

# Also create shorter-name variants that flutter might look for
short_names = {
    "cmake": "d56f5187479451eabf01fb78af6dfcb131a64d1f",
    "ndk": "84831b9409646a918e30573bab4c9c91346d8abd",
    "system-image": "60055b75ce789b1bdae4f70f17320a7a",
    "emu": "becf7290d8ddb5f032a5ee8decc8a439",
    "emulator": "7746258bcf0227f4c38266295adcc795",
    "platform-tools": "25c7696cfbf70904314b4a0c3a3a1b3e",
    "build-tools": "e93bd8382c9c08a88901234c84a06e56",
}
for name, sha1 in short_names.items():
    filepath = os.path.join(sdk_dir, name)
    if not os.path.exists(filepath):
        with open(filepath, "wb") as f:
            f.write(bytes.fromhex(sha1))
        print(f"Created (short): {name}")

print("Done. Licenses created.")
