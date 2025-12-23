# Dotcat PetCare - Cat Care Assistant

A comprehensive Flutter application for managing your cat's health, reminders, and daily care routines.

## 🐱 Features

- **Cat Management**: Add, edit, and manage multiple cat profiles
- **Reminders**: Set up recurring reminders for vaccines, medications, food, vet visits, and more
- **Weight Tracking**: Track your cat's weight over time with visual charts
- **Calendar View**: View all events in an interactive calendar
- **Multi-language Support**: Turkish, English, German, Spanish, and Arabic
- **Cloud Sync**: All data is synced with Firebase (Firestore + Storage)
- **Notifications**: Local notifications for reminders
- **Dark Mode**: Full dark mode support

## 🔐 Authentication

- Google Sign-In
- Email/Password
- Anonymous Sign-In

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.10.3 or higher)
- Firebase project with:
  - Authentication enabled (Google, Email/Password, Anonymous)
  - Firestore Database
  - Cloud Storage
  - iOS and Android apps configured

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/dotcat.git
cd dotcat
```

2. Install dependencies:
```bash
flutter pub get
```

3. Firebase Setup:
   - Download `GoogleService-Info.plist` from Firebase Console (iOS)
   - Download `google-services.json` from Firebase Console (Android)
   - Place them in:
     - `ios/Runner/GoogleService-Info.plist`
     - `android/app/google-services.json`

4. Configure Firebase Rules:
   - Firestore: Copy `firestore.rules` to Firebase Console → Firestore → Rules
   - Storage: Copy `storage.rules` to Firebase Console → Storage → Rules

5. Run the app:
```bash
flutter run
```

## 📱 Build for Production

### Android

1. Create a keystore:
```bash
keytool -genkey -v -keystore ~/dotcat-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias dotcat
```

2. Update `android/app/build.gradle.kts` with your keystore configuration

3. Build:
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS

1. Open `ios/Runner.xcworkspace` in Xcode
2. Configure signing & capabilities
3. Build:
```bash
flutter build ios --release
```

## 📋 Project Structure

```
lib/
├── core/           # Core utilities, services, constants
├── data/           # Models and database
├── features/       # Feature modules
│   ├── auth/       # Authentication
│   ├── cats/       # Cat management
│   ├── reminders/  # Reminder management
│   ├── weight/     # Weight tracking
│   └── home/       # Home screen, calendar, settings
└── widgets/        # Reusable widgets
```

## 🔧 Configuration

### Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Enable Authentication methods:
   - Google Sign-In
   - Email/Password
   - Anonymous
3. Create Firestore Database
4. Create Cloud Storage bucket
5. Configure security rules (see `firestore.rules` and `storage.rules`)

### Android Configuration

- Application ID: `com.dotcat.petcare`
- Minimum SDK: As per Flutter defaults
- Target SDK: Latest Android SDK

### iOS Configuration

- Bundle Identifier: `com.dotcat.petcare`
- Minimum iOS Version: 15.0
- Capabilities: Push Notifications

## 📝 Important Notes

- **API Keys**: Never commit `GoogleService-Info.plist` or `google-services.json` to version control
- **Signing**: Production builds require proper signing configuration
- **Firebase Rules**: Must be configured in Firebase Console before production use

## 🐛 Known Issues

- Completion tracking is currently stored locally (SQLite). Cloud sync will be added in a future update.

## 📄 License

[Your License Here]

## 👥 Contributing

[Contributing guidelines]

## 📞 Support

[Support contact information]
