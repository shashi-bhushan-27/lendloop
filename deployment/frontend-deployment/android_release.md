# Android APK Release Build Guide

## Prerequisites
- Flutter SDK 3.x
- Android SDK with Build Tools
- A keystore file for signing

---

## Step 1 — Generate a Keystore

```bash
keytool -genkey -v -keystore lendloop-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias lendloop
```

Keep `lendloop-release.jks` safe — never commit to git.

---

## Step 2 — Configure key.properties

Create `frontend/android/key.properties`:
```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=lendloop
storeFile=../lendloop-release.jks
```

---

## Step 3 — Configure android/app/build.gradle

The `build.gradle` should load key.properties and use it for the release signing config.

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

---

## Step 4 — Build APK

```bash
cd frontend
flutter build apk --release
```

Output: `frontend/build/app/outputs/flutter-apk/app-release.apk`

## Step 5 — Build App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

Output: `frontend/build/app/outputs/bundle/release/app-release.aab`

---

## Update Base URL for Production

Before building, update `frontend/lib/core/constants/app_constants.dart`:
```dart
static const String baseUrl = 'https://your-backend.onrender.com/api/v1';
```
