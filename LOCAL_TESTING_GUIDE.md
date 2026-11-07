# Eggova Local & Mobile Testing Guide

A quick-reference guide for running and testing the **Eggova** mobile app (Flutter) with the local **Spring Boot backend** on Android devices.

---

## Architecture Overview

```
                      ┌────────────────────────────────────────┐
                      │   Your PC (Local Development)          │
                      │                                        │
                      │   • Spring Boot Backend (Port 3000)    │
                      │   • Cloudflare Tunnel / Local Wi-Fi    │
                      └──────────────────┬─────────────────────┘
                                         │
              ┌──────────────────────────┴──────────────────────────┐
              ▼                                                     ▼
    [Option 1: Same Wi-Fi]                                [Option 2: Mobile Data (4G/5G)]
• Phone connected to same Wi-Fi                      • Phone on Cellular Network (No Wi-Fi)
• Connects to: `http://<PC_IP>:3000/api`              • Connects to: `https://<tunnel>.trycloudflare.com/api`
```

---

## 1. Prerequisites

1. **Start the Backend**:
   - Open the project in your IDE (VSCode / IntelliJ / Antigravity).
   - Run `EggovaApplication.java`.
   - Ensure the console prints:
     ```
     Tomcat started on port 3000 (http)
     ```

2. **Flutter Path**:
   All commands below use the installed Flutter binary at:
   ```cmd
   "D:\flutter_windows_3.38.7-stable\flutter\bin\flutter.bat"
   ```

---

## 2. Testing Option A: Same Wi-Fi Network

Use this when both your PC and Android mobile phone are connected to the **same Wi-Fi router**.

### Step 1: Check Your PC's Wi-Fi IP Address
Open Command Prompt and run:
```cmd
ipconfig
```
Find the **IPv4 Address** under `Wireless LAN adapter Wi-Fi` (e.g. `192.168.1.4`).

> **Note:** If your PC's IP changed from `192.168.1.4`, update `localIp` in `eggova_app/lib/config/constants.dart`.

### Step 2: Build the APK
Open Command Prompt and run:
```cmd
cd c:\Eggova\Eggova\eggova_app
"D:\flutter_windows_3.38.7-stable\flutter\bin\flutter.bat" build apk --split-per-abi
```

### Step 3: Install on Android Phone
Navigate to:
```
eggova_app\build\app\outputs\flutter-apk\
```
Transfer and install:
👉 **`app-arm64-v8a-release.apk`** *(~19 MB, compatible with modern Android phones)*.

---

## 3. Testing Option B: Over Mobile Data (4G / 5G) via Cloudflare Tunnel

Use this when your phone is on **cellular data** (not on the same Wi-Fi), or when testing remotely.

### Step 1: Start the Cloudflare Tunnel
In `c:\Eggova\Eggova`, double-click **`start-tunnel.bat`** or run:
```cmd
cd c:\Eggova\Eggova
tools\cloudflared.exe tunnel --url http://localhost:3000
```

Wait 5–10 seconds until you see the banner with your temporary public HTTPS link:
```text
+--------------------------------------------------------------------------------------------+
|  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
|  https://xxxx-xxxx-xxxx.trycloudflare.com                                                  |
+--------------------------------------------------------------------------------------------+
```
Copy that URL (e.g. `https://shaved-counsel-least-desperate.trycloudflare.com`).

> **Important:** Keep this terminal window **OPEN** while testing. Closing it stops the tunnel.

### Step 2: Build APK with the Tunnel URL
Open a new terminal window and run:
```cmd
cd c:\Eggova\Eggova\eggova_app
"D:\flutter_windows_3.38.7-stable\flutter\bin\flutter.bat" build apk --split-per-abi --dart-define=API_URL=https://<YOUR-URL>.trycloudflare.com/api
```

*(Example: `--dart-define=API_URL=https://shaved-counsel-least-desperate.trycloudflare.com/api`)*

### Step 3: Install & Test
1. Transfer and install:
   `eggova_app\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`
2. On your phone:
   - **Turn OFF Wi-Fi**
   - **Turn ON Mobile Data (4G/5G)**
3. Open Eggova and test sign in or registration.

---

## 4. Test Accounts & Credentials

| Role | Login Type | Credential | Password | Notes |
|---|---|---|---|---|
| **Admin** | Email | `admin@eggova.com` | `admin123` | Switch via "Admin Login" toggle |
| **Customer** | Phone | `9999999999` | `user123` | Seeded demo user for quick testing |
| **New Customer** | Phone | Any 10-digit number | Your choice (min 6 chars) | Use the **"Sign Up"** page in app |

---

## 5. Why `--split-per-abi`?

When you run `flutter build apk`, Flutter bundles binaries for three CPU architectures:
- `arm64-v8a` (Modern 64-bit phones — 99% of devices today)
- `armeabi-v7a` (Older 32-bit phones)
- `x86_64` (Emulators)

| Build Command | Output Size | File Name |
|---|---|---|
| `flutter build apk` (fat APK) | **~157 MB** | `app-release.apk` |
| `flutter build apk --split-per-abi` | **~19.6 MB** | `app-arm64-v8a-release.apk` |

👉 **Always install `app-arm64-v8a-release.apk` for the smallest and fastest install.**

---

## 6. Troubleshooting

- **Error: `DioException [bad response]: status code 308`**
  - Make sure the backend is running on your PC.
  - Make sure `API_URL` is pointing to `http://<PC_IP>:3000/api` or `https://<tunnel>.trycloudflare.com/api`, NOT the production fallback.
- **Connection Refused / Timeout**:
  - Verify your PC and mobile phone are on the exact same Wi-Fi SSID.
  - Windows Firewall: Ensure port 3000 is allowed for private networks.
- **Tunnel URL Changed**:
  - Each time you restart `cloudflared.exe` without an account, Cloudflare assigns a new random subdomain. If you restart it, rebuild the APK with the new URL.
