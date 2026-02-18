# 🥚 Eggova Project Setup & Run Guide

This guide explains how to start the Eggova project (Backend & App) from scratch.

---

## 🏗️ Architecture Explained

### 1. **Flutter** (The Artist 🎨)
- **Role:** Flutter is the UI toolkit. It draws the buttons, text, and images on the screen.
- **Why we use it:** It lets us write code once (in Dart) and run it on Android, iOS, Web, and Desktop.
- **Analogy:** Think of Flutter as the **Paint & Canvas**. You describe the picture, and it draws it.

### 2. **Android Studio** (The Toolbox 🧰)
- **Role:** Android Studio provides the underlying tools (SDK, Gradle, compilers) that Flutter needs to build an actual Android app (`.apk`).
- **Why we use it:** Flutter cannot build Android apps on its own; it relies on the Android SDK tools provided by Android Studio.
- **Analogy:** Think of Android Studio as the **Factory**. It takes the Flutter "painting" and frames/packages it into a real product that works on an Android phone.

---

## 🚀 How to Start the Project (Step-by-Step)

You need to run **two separate terminals**: one for the Backend, one for the App.

### Step 1: Start the Backend Server (Terminal 1)
The backend holds the database and logic. The app won't work without it.

1. Open a new terminal (PowerShell or Command Prompt).
2. Run these commands:
   ```powershell
   cd c:\Users\Public\Eggova\backend
   node server.js
   ```
3. **Keep this terminal open!** You should see:
   > `✅ Database connected`
   > `✅ Models synchronized`
   > `🚀 Eggova API running on port 3000`

### Step 2: Connect Your Phone
1. Connect your Android phone to your PC via USB.
2. Ensure **USB Debugging** is ON (in Developer Options).
3. Ensure your phone and PC are on the **SAME WiFi Network**.

### Step 3: Start the Flutter App (Terminal 2)
1. Open a **second** terminal.
2. Run these commands:
   ```powershell
   cd c:\Users\Public\Eggova\eggova_app
   flutter run
   ```
3. Wait for the app to build and install on your phone.
4. **Login Details:**
   - **User:** `ravi@test.com` / `user123`
   - **Admin:** `admin@eggova.com` / `admin123`

---

## 🛠️ Troubleshooting

### "Connection Refused" or "Network Error"
- **Cause:** Your phone cannot reach the backend server.
- **Fix:**
  1. Check if your PC's IP address changed. Run `ipconfig` in a terminal.
  2. Should be something like `192.168.0.107`.
  3. If changed, update `lib/config/constants.dart` in the `eggova_app` folder:
     ```dart
     static const String apiBaseUrl = 'http://192.168.0.X:3000/api';
     ```
  4. Restart the app (press `R` in the Flutter terminal).

### "Install Failed User Restricted"
- **Cause:** Xiaomi/Redmi security blocking USB install.
- **Fix:** Enable "Install via USB" in Developer Options (requires SIM card).
