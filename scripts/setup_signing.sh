#!/bin/bash
set -e

cd android

# 1. Create key.properties
cat > key.properties <<EOF
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=upload-keystore.jks
EOF

# 2. Decode keystore to app/
echo "${ANDROID_KEYSTORE_BASE64}" | base64 --decode > app/upload-keystore.jks

# 3. Modify app/build.gradle
python3 << 'PYEOF'
path = 'app/build.gradle'
with open(path) as f:
    content = f.read()

if 'keystoreProperties' in content:
    print('Already configured, skipping')
    raise SystemExit(0)

loader = """def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {"""
content = content.replace('android {', loader, 1)

signing = """    signingConfigs {
        release {
            keyAlias keystoreProperties["keyAlias"]
            keyPassword keystoreProperties["keyPassword"]
            storeFile keystoreProperties["storeFile"] ? file(keystoreProperties["storeFile"]) : null
            storePassword keystoreProperties["storePassword"]
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
"""
content = content.replace('    buildTypes {', signing + '    buildTypes {', 1)
content = content.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.release')

with open(path, 'w') as f:
    f.write(content)
print('build.gradle updated')
PYEOF

echo "Signing setup complete"
