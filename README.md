# 🚗 SathChalo (साथ चलो) — Peer-to-Peer Ride Sharing

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

> **"Sath Chalo" (Ride Together)** — A production-ready, peer-to-peer ride-sharing platform that connects drivers and passengers in real-time.

---

## ⚡ Features

-   **400m Corridor Matching**: Advanced matching engine that finds passengers directly on a driver's route.
-   **Real-time Tracking**: Live location updates using Google Maps.
-   **Secure OTP Verification**: Ensures safe pickups with unique ride codes.
-   **Profile Management**: User profiles with ride history.
-   **Cross-platform**: Seamless performance on Android and iOS.

---

## 🏗️ Technical Stack

-   **Frontend**: Flutter (Riverpod for State Management)
-   **Backend**: Supabase (PostgreSQL + PostGIS for spatial queries)
-   **Maps**: Google Maps SDK for Flutter
-   **Security**: `flutter_dotenv` for environment variable management

---

## ⚙️ Setup & Installation

### 1. Prerequisites
-   Flutter SDK (3.13.0+)
-   Supabase Account
-   Google Cloud Console (Maps/Directions API keys)

### 2. Clone & Install
```powershell
git clone <your-repository-url>
cd sathchalo
flutter pub get
```

### 3. Environment Config
Create a `.env` file in the root directory and add your credentials:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_MAPS_API_KEY=your-api-key
```

### 4. Database Initialization
This project requires **PostGIS** for spatial routing. Run the migrations located in `supabase/migrations/` in your Supabase SQL editor.

---

## 🚀 Running the App
```powershell
flutter run
```

---

## 🔒 Security Notice
The project uses `flutter_dotenv`. Never commit your `.env` file to version control. The `.gitignore` in this project is already configured to keep your credentials safe.

---

## 📂 Project Structure
```text
lib/
├── core/           # Theme, constants, utils
├── data/           # Repositories & API datasources
├── domain/         # Entities & business logic
└── presentation/   # UI widgets, screens, and providers
```