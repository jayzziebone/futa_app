# 🚀 FUTA - Automated CI/CD Deployment Guide (GitHub Actions)

This guide documents the complete automated CI/CD pipeline for **FUTA** to automatically build and deploy the app to **Google Play Console (Internal Testing)** and **Apple TestFlight** on every push to the `main` branch.

---

## 📁 1. Workflow Architecture & File Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy_android.yml      # Dedicated Android -> Google Play workflow
│       └── deploy_ios.yml          # Dedicated iOS -> TestFlight workflow
├── GITHUB_ACTIONS_DEPLOYMENT.md    # This setup guide
├── LAUNCH_GUIDE.md
└── Futa/
    ├── android/
    │   └── key.properties          # Generated dynamically in CI
    └── ios/
        └── ExportOptions.plist      # iOS Archive Export Configuration
```

---

## ⚙️ 2. Workflow Definition (`.github/workflows/deploy.yml`)

The workflow automatically:
1. Triggers on any push to `main` modifying files in `Futa/` or the workflow itself.
2. Injects monotonically incrementing build numbers using `${{ github.run_number }}` so release uploads never collide.
3. Builds and signs the Android App Bundle (`.aab`) and uploads it to Google Play Console.
4. Initializes a secure macOS runner keychain, installs Apple certificates and provisioning profiles, builds the `.ipa` and uploads it to TestFlight.

```yaml
name: Deploy to Google Play & TestFlight

on:
  push:
    branches:
      - main
    paths:
      - 'Futa/**'
      - '.github/workflows/deploy.yml'
  workflow_dispatch:

concurrency:
  group: deploy-main
  cancel-in-progress: false

jobs:
  # =========================================================================
  # 📱 ANDROID DEPLOYMENT (Google Play Console - Internal Testing)
  # =========================================================================
  deploy-android:
    name: Build & Deploy Android to Google Play
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: Futa

    steps:
      - name: 📥 Checkout Repository
        uses: actions/checkout@v4

      - name: ☕ Setup Java (JDK 17)
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
          cache: 'gradle'

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true
          cache-key: 'flutter-:os:-:channel:-:version:-:arch:-:hash:'

      - name: 📦 Install Flutter Dependencies
        run: flutter pub get

      - name: 🔑 Decode Android Keystore & Setup key.properties
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
        run: |
          echo "$KEYSTORE_BASE64" | base64 --decode > android/app/futa-release-key.jks
          cat <<EOF > android/key.properties
          storePassword=$KEYSTORE_PASSWORD
          keyPassword=$KEY_PASSWORD
          keyAlias=$KEY_ALIAS
          storeFile=futa-release-key.jks
          EOF

      - name: 🛠️ Build Android App Bundle (.aab)
        run: |
          flutter build appbundle --release --build-number=${{ github.run_number }}

      - name: 🚀 Upload to Google Play Console
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.futa.app
          releaseFiles: Futa/build/app/outputs/bundle/release/app-release.aab
          track: internal
          status: completed

  # =========================================================================
  # 🍏 iOS DEPLOYMENT (Apple TestFlight / App Store Connect)
  # =========================================================================
  deploy-ios:
    name: Build & Deploy iOS to TestFlight
    runs-on: macos-14
    defaults:
      run:
        working-directory: Futa

    steps:
      - name: 📥 Checkout Repository
        uses: actions/checkout@v4

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: 📦 Install Flutter Dependencies
        run: flutter pub get

      - name: 🍎 Install Apple Certificate and Provisioning Profile
        env:
          BUILD_CERTIFICATE_BASE64: ${{ secrets.IOS_P12_BASE64 }}
          P12_PASSWORD: ${{ secrets.IOS_P12_PASSWORD }}
          BUILD_PROVISION_PROFILE_BASE64: ${{ secrets.IOS_PROVISION_PROFILE_BASE64 }}
          KEYCHAIN_PASSWORD: ${{ secrets.IOS_KEYCHAIN_PASSWORD || 'temporary-ci-keychain-pass' }}
        run: |
          KEYCHAIN_PATH=$RUNNER_TEMP/build.keychain
          security create-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security set-keychain-settings -lut 21600 $KEYCHAIN_PATH
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH

          CERTIFICATE_PATH=$RUNNER_TEMP/build_cert.p12
          echo "$BUILD_CERTIFICATE_BASE64" | base64 --decode > $CERTIFICATE_PATH
          security import $CERTIFICATE_PATH -k $KEYCHAIN_PATH -P "$P12_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" $KEYCHAIN_PATH
          security list-keychain -d user -s $KEYCHAIN_PATH

          PROVISIONING_PROFILE_PATH=$RUNNER_TEMP/profile.mobileprovision
          echo "$BUILD_PROVISION_PROFILE_BASE64" | base64 --decode > $PROVISIONING_PROFILE_PATH
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          cp $PROVISIONING_PROFILE_PATH ~/Library/MobileDevice/Provisioning\ Profiles/

      - name: 🛠️ Build iOS Archive (.ipa)
        run: |
          flutter build ipa --release --build-number=${{ github.run_number }} --export-options-plist=ios/ExportOptions.plist

      - name: 🚀 Upload IPA to App Store Connect / TestFlight
        env:
          APP_STORE_CONNECT_API_KEY_BASE64: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY_BASE64 }}
          KEY_ID: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
          ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
        run: |
          mkdir -p ~/.appstoreconnect/private_keys
          echo "$APP_STORE_CONNECT_API_KEY_BASE64" | base64 --decode > ~/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8

          xcrun altool --upload-app \
            --type ios \
            --file build/ios/ipa/futa.ipa \
            --apiKey "$KEY_ID" \
            --apiIssuer "$ISSUER_ID"
```

---

## 🔐 3. Required GitHub Repository Secrets

Configure these in **GitHub Repository** $\rightarrow$ **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions** $\rightarrow$ **New repository secret**:

### 🤖 Android Secrets

| Secret Name | How to Obtain / Format |
| :--- | :--- |
| `ANDROID_KEYSTORE_BASE64` | Run `base64 -i ~/futa-release-key.jks | pbcopy` and paste the output. |
| `ANDROID_KEYSTORE_PASSWORD` | The password chosen when creating the `.jks` file. |
| `ANDROID_KEY_PASSWORD` | The key alias password (usually same as keystore password). |
| `ANDROID_KEY_ALIAS` | Alias name (`futa`). |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | The raw JSON key file downloaded from Google Cloud IAM with Play Console permissions. |

### 🍏 iOS Secrets

| Secret Name | How to Obtain / Format |
| :--- | :--- |
| `IOS_P12_BASE64` | Run `base64 -i Certificates.p12 | pbcopy` (Exported Distribution cert from Keychain Access). |
| `IOS_P12_PASSWORD` | Password set during the `.p12` export from Keychain Access. |
| `IOS_PROVISION_PROFILE_BASE64` | Run `base64 -i Futa_AppStore.mobileprovision | pbcopy`. |
| `APP_STORE_CONNECT_KEY_ID` | 10-character Key ID from App Store Connect API keys (e.g. `2X9R4HXF34`). |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer UUID from App Store Connect (e.g. `57246542-96fe-1a63-e053-0824d011072a`). |
| `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | Run `base64 -i AuthKey_<KEY_ID>.p8 | pbcopy`. |

---

## 📄 4. iOS Export Configuration (`Futa/ios/ExportOptions.plist`)

Create `Futa/ios/ExportOptions.plist` with your Apple Developer Team ID:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>YOUR_APPLE_TEAM_ID</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.futa.app</key>
        <string>YOUR_PROVISIONING_PROFILE_NAME</string>
    </dict>
</dict>
</plist>
```

---

## 📝 5. Step-by-Step Setup Guide

### 📱 Android Setup (Google Play Console)
1. **Keystore Generation**:
   ```bash
   keytool -genkey -v -keystore ~/futa-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias futa
   ```
2. **Encode to Base64**:
   ```bash
   base64 -i ~/futa-release-key.jks | pbcopy
   ```
3. **Google Play API Access**:
   - Go to **Google Cloud Console** $\rightarrow$ **IAM & Admin** $\rightarrow$ **Service Accounts** $\rightarrow$ **Create Service Account** (`futa-play-publisher`).
   - Create and download a **JSON Key**.
   - In **Google Play Console** $\rightarrow$ **API access**, link the project and grant the service account permissions on `com.futa.app` to **Create & edit releases to testing tracks**.
   - Paste the JSON key contents into `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

---

### 🍏 iOS Setup (Apple Developer & App Store Connect)
1. **App Store Connect API Key**:
   - Open [App Store Connect](https://appstoreconnect.apple.com) $\rightarrow$ **Users and Access** $\rightarrow$ **Integrations** $\rightarrow$ **App Store Connect API**.
   - Click **+** (Generate API Key), name it `GitHub CI`, set Access to **App Manager** or **Admin**.
   - Copy **Issuer ID**, **Key ID**, and download `AuthKey_<KEY_ID>.p8`.
   - Encode the `.p8` file: `base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy`.
2. **Export Distribution Certificate (.p12)**:
   - Open **Keychain Access** on your Mac $\rightarrow$ find your **Apple Distribution Certificate**.
   - Right-click $\rightarrow$ **Export...** $\rightarrow$ save as `.p12` with a password.
   - Encode the `.p12`: `base64 -i Certificates.p12 | pbcopy`.
3. **Export Provisioning Profile**:
   - In [Apple Developer Portal](https://developer.apple.com) $\rightarrow$ **Profiles** $\rightarrow$ download your **App Store distribution profile** for `com.futa.app`.
   - Encode the profile: `base64 -i Futa_AppStore.mobileprovision | pbcopy`.

---

## 🚀 6. Triggering Deployments

Every `git push origin main` that updates the `Futa/` directory will automatically start the pipeline in your GitHub repository's **Actions** tab.

Builds are tagged with `--build-number=${{ github.run_number }}` and will appear in:
* **Google Play Console**: Under **Testing > Internal testing**.
* **Apple App Store Connect**: Under **Apps > Futa > TestFlight**.
