# 🚀 FUTA - Production Readiness & Multi-Platform Launch Guide

This document provides a complete assessment of the FUTA application's readiness along with step-by-step instructions for deploying to **Google Play Store**, **iOS TestFlight**, and **Web**.

---

## 📊 Overall Readiness Status: **90% Ready**

| Component | Status | Notes |
| :--- | :--- | :--- |
| **Backend API (Cloud Run)** | ✅ **Production Ready** | Deployed on Google Cloud Run (`https://futa-backend-43008970087.us-central1.run.app`). Public x509 cert validation and role endpoints active. |
| **Database & RLS (Supabase)** | ✅ **Production Ready** | Split profile tables (`profiles`, `school_profiles`, `merchant_profiles`) and security policies active. |
| **Application Logic & UI** | ✅ **Production Ready** | Cash adjustments, auto-cascading installment payments, role routing, and mobile/web layouts verified. |
| **App Branding & Bundle ID** | ✅ **Completed** | Launcher icons generated, app display name set to **Futa**, bundle ID updated to `com.futa.app`. |
| **iOS SMS OTP Authentication** | ✅ **Verified & Working** | Custom URL scheme (`app-1-43008970087-ios-1ff25b3763a05c929333c2`) registered and tested on physical iPhone. |
| **Build Signing & Deployment** | ⚠️ **Needs Upload** | Ready for Google Play Console `.aab`, iOS TestFlight `.ipa`, and Firebase Hosting web upload. |

---

## 📱 1. Google Play Console (Android `.aab`)

### Step 1: Generate Release Keystore
Run the following command in your terminal to generate a production signing key:
```bash
keytool -genkey -v -keystore ~/futa-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias futa
```

### Step 2: Configure `key.properties`
Create a file named `Futa/android/key.properties` with the following content:
```ini
storePassword=<YOUR_KEYSTORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=futa
storeFile=/Users/jayzziebone/futa-release-key.jks
```

### Step 3: Enable Release Signing in Gradle
Edit `Futa/android/app/build.gradle.kts` to load `key.properties` for the release build type:
```kotlin
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### Step 4: Add Keystore SHA Fingerprints to Firebase
1. Extract your keystore SHA-1 and SHA-256 fingerprints:
   ```bash
   keytool -list -v -keystore ~/futa-release-key.jks -alias futa
   ```
2. Open **Firebase Console** (`futa-1c8d8`) > **Project Settings** > **Android App**.
3. Add both **SHA-1** and **SHA-256** fingerprints so Phone Auth SMS OTP works on production builds.

### Step 5: Build App Bundle & Upload
1. Build the release `.aab` bundle:
   ```bash
   cd Futa
   flutter build aab --release
   ```
2. Output path: `Futa/build/app/outputs/bundle/release/app-release.aab`
3. Go to [Google Play Console](https://play.google.com/console), create an app listing, complete the Store Listing & Privacy Policy, and upload your `.aab` file to **Internal Testing** or **Production**.

---

## 🍏 2. iOS TestFlight (App Store Connect `.ipa`)

### Step 1: Apple Developer Portal Setup
1. Log into [Apple Developer Portal](https://developer.apple.com).
2. Register your App ID (e.g. `com.futa.app` or `com.futa.frontend`).
3. Enable **Push Notifications** under App Capabilities.

### Step 2: Configure Firebase APNs Key
1. In Apple Developer Portal, generate an **APNs Key** (`.p8` file).
2. In **Firebase Console** > **Project Settings** > **iOS App**, upload the APNs Auth Key (`.p8`) and enter your Key ID & Team ID. This enables native iOS SMS OTP verification.

### Step 3: Build Release IPA
1. Navigate to the `Futa` folder and build the release archive:
   ```bash
   cd Futa
   flutter build ipa --release
   ```
2. Output path: `Futa/build/ios/ipa/futa.ipa`

### Step 4: Upload to App Store Connect
- Open Xcode (`open Futa/ios/Runner.xcworkspace`), select **Product > Archive**, and click **Distribute App**.
- Alternatively, upload `futa.ipa` using the **Apple Transporter** app from the Mac App Store.

### Step 5: TestFlight Distribution
1. Go to [App Store Connect](https://appstoreconnect.apple.com) > **Apps** > **Futa** > **TestFlight**.
2. Add internal or external testers by email to begin testing.

---

## 🌐 3. Web Deployment (Firebase Hosting / Vercel)

### Step 1: Authorize Web Domain in Firebase
1. Open **Firebase Console** > **Authentication** > **Settings** > **Authorized Domains**.
2. Add your deployment domain (e.g., `futa-app.web.app` or your custom domain `app.futa.com`).

### Step 2: Build Web Release
```bash
cd Futa
flutter build web --release
```
Output directory: `Futa/build/web/`

### Step 3: Deploy
- **Firebase Hosting**:
  ```bash
  npx -y firebase-tools deploy --only hosting
  ```
- **Vercel / Netlify**:
  Connect your GitHub repository `https://github.com/jayzziebone/futa_app.git` and set build directory to `Futa/build/web`.
