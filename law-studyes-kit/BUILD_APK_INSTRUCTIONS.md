# Law Studyes — Full Offline Android APK & Auto-Sync Guide

## Option A (Easiest — No Android Studio Needed): 1-Click Cloud APK Build on GitHub
1. Create a free GitHub repository named `law-studyes` and upload/push all files from this folder.
2. Open the **Actions** tab on GitHub -> click **Build Offline Law Studyes APK** -> click **Run workflow**.
3. Wait ~4 minutes: GitHub automatically scrapes all live subjects & notes across **all Years & Semesters** from `nyayasaral.com`, bundles the entire offline database inside the app, and compiles **`LawStudyes-Offline.apk`**.
4. Download **`LawStudyes-Offline-APK`** from the completed workflow's **Artifacts** section and install it on your Android phone!

### Built-in Indian Google Voice Setup on Android
The APK uses `@capacitor-community/text-to-speech` to call Android's native **Google Speech Recognition & Synthesis** engine with `en-IN` (Indian English) and `te-IN` (Telugu) automatically:
- On your phone: **Settings -> System -> Languages & input -> Text-to-speech output -> Preferred engine: Speech Recognition & Synthesis from Google -> Language: English (India)**.
- Download the offline `English (India)` voice pack in Google TTS settings so audio reading runs 100% offline with zero data usage.

## Option B: Build Locally on Windows PC (PowerShell)
```powershell
pip install -r requirements.txt
python scrape_nyayasaral.py
npm install
npx cap add android
npx cap sync android
cd android
.\gradlew.bat assembleDebug
```
APK output: `android\app\build\outputs\apk\debug\app-debug.apk`
