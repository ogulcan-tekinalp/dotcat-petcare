# DotCat PetCare - AI Assistant Guide

## Project Overview

DotCat is a comprehensive Flutter mobile application for managing cat health, care routines, and reminders. The app uses Firebase for authentication, cloud storage, and real-time data synchronization.

**Version:** 1.0.0+2
**Flutter SDK:** ^3.10.3
**Primary Language:** Dart
**Platforms:** iOS and Android

## Architecture

### State Management
- **Riverpod** (`flutter_riverpod: ^2.6.1`) for reactive state management
- Providers located in feature-specific `providers/` directories

### Project Structure

```
lib/
├── core/
│   ├── constants/       # App-wide constants (spacing, reminder types, etc.)
│   ├── providers/       # Global providers (language, theme)
│   ├── services/        # Core services (auth, firestore, storage, sync, notifications)
│   ├── theme/          # Theme configuration and dark mode
│   ├── utils/          # Helper utilities (date, localization, notifications)
│   └── widgets/        # Reusable UI components (error states, toasts, loaders)
├── data/               # Data models and local database (SQLite)
├── features/           # Feature-based modules
│   ├── auth/           # Authentication (login, sign-up)
│   ├── cats/           # Cat profile management
│   ├── home/           # Home screen, calendar, settings
│   ├── insights/       # Health insights and analytics
│   ├── onboarding/     # Splash and onboarding screens
│   ├── reminders/      # Reminder CRUD and completion tracking
│   └── weight/         # Weight tracking with charts
└── main.dart           # App entry point
```

## Key Technologies

### Firebase Stack
- **Authentication:** Google Sign-In, Email/Password, Anonymous, Apple Sign-In
- **Firestore:** Real-time cloud database for cats, reminders, and completions
- **Storage:** Cloud storage for cat images
- **Messaging:** Push notifications (`firebase_messaging: ^15.1.6`)

### Local Storage
- **SQLite** (`sqflite: ^2.4.2`) for offline-first data persistence
- **Shared Preferences** for user settings

### UI/UX Features
- **Multi-language Support:** Turkish, English, German, Spanish, Arabic (via `intl`)
- **Calendar:** `table_calendar: ^3.1.2` for event visualization
- **Charts:** `fl_chart: ^0.69.2` for weight trend graphs
- **Animations:** `lottie`, `flutter_animate`, `shimmer`, `confetti`
- **Image Handling:** `image_picker`, `image_cropper`, `cached_network_image`
- **Home Widgets:** `home_widget: ^0.7.0` for iOS/Android widgets
- **Haptic Feedback:** `vibration: ^2.0.1`

## Important Services

### 1. AuthService (`lib/core/services/auth_service.dart`)
Handles Firebase authentication with Google, Apple, Email/Password, and Anonymous sign-in.

### 2. FirestoreService (`lib/core/services/firestore_service.dart`)
Manages all Firestore operations for cats, reminders, and reminder completions.

### 3. SyncService (`lib/core/services/sync_service.dart`)
Synchronizes local SQLite data with Firebase Firestore.

### 4. NotificationService (`lib/core/utils/notification_service.dart`)
Manages local notifications for reminders using `flutter_local_notifications`.

### 5. WidgetService (`lib/core/services/widget_service.dart`)
Updates home screen widgets on iOS and Android.

### 6. BackgroundService (`lib/core/services/background_service.dart`)
Handles background tasks and data synchronization.

### 7. InsightsService (`lib/core/services/insights_service.dart`)
Generates health insights and analytics for cats.

## Data Models

### Cat
- Profile information (name, breed, birthdate, gender, photo)
- Stored in Firestore: `cats/{userId}/user_cats/{catId}`

### Reminder
- Recurring reminders (vaccines, medications, food, grooming, vet visits, etc.)
- Stored in Firestore: `reminders/{userId}/user_reminders/{reminderId}`

### ReminderCompletion
- Tracks when reminders are completed
- Stored in Firestore: `reminder_completions/{userId}/completions/{completionId}`
- Real-time sync with local SQLite database

## Security Rules

### Firestore (`firestore.rules`)
- Users can only access their own data under their `userId`
- Collections are scoped: `{collection}/{userId}/user_{collection}/{docId}`

### Storage (`storage.rules`)
- Users can only read/write files in their own directory: `users/{userId}/...`

## Recent Changes (Git Status)

- Firebase integration completed for iOS and Android
- Home screen widgets added (iOS and Android)
- Real-time sync for reminder completions implemented
- Critical data sync issues resolved
- Test features and non-functional settings removed
- Apple Store preparation fixes documented in `APPLE_STORE_FIXES.md`

## Build Configuration

### Android
- **Package:** `com.dotcat.petcare`
- **Build:** `android/app/build.gradle.kts`
- **Manifest:** `android/app/src/main/AndroidManifest.xml`
- **Widget Provider:** `android/app/src/main/kotlin/com/example/dotcat/DotCatWidgetProvider.kt`

### iOS
- **Bundle ID:** `com.dotcat.petcare`
- **Min iOS:** 15.0
- **Project:** `ios/Runner.xcodeproj/project.pbxproj`
- **Entitlements:** `ios/Runner.entitlements`, `ios/DotCatWidgetExtension.entitlements`
- **Widget:** `ios/DotCatWidget/DotCatWidget.swift`
- **Podfile:** `ios/Podfile`

## Common Tasks

### Adding a New Feature
1. Create feature module in `lib/features/{feature_name}/`
2. Structure: `data/`, `presentation/`, `providers/`
3. Add models to `lib/data/models/`
4. Update Firestore service if cloud sync needed
5. Add localization strings in `lib/core/utils/localization.dart`

### Adding a New Reminder Type
1. Update `lib/core/constants/reminder_constants.dart`
2. Add translations in all languages
3. Update UI icons in reminder screens
4. Test notification scheduling

### Database Migrations
- SQLite schema in `lib/data/database/`
- Always increment database version
- Provide migration logic in `onUpgrade`

### Localization
- All strings managed in `lib/core/utils/localization.dart`
- Use `AppLocalization.of(context)` for translated strings
- Supported languages: `tr`, `en`, `de`, `es`, `ar`

## Testing

- Test file: `test/widget_test.dart`
- Run tests: `flutter test`
- Test scenarios documented in `TEST_SCENARIOS.md`

## Important Notes

1. **Never commit Firebase config files:**
   - `ios/Runner/GoogleService-Info.plist`
   - `android/app/google-services.json`

2. **Cloud Sync Strategy:**
   - Offline-first with SQLite
   - Real-time Firestore streams for live updates
   - Conflict resolution handled by timestamp

3. **Widget Updates:**
   - Call `WidgetService` after data changes
   - Widgets show today's pending reminders

4. **Notifications:**
   - Scheduled using timezone-aware scheduling
   - Permissions requested on first use
   - Configurable per reminder

5. **Image Handling:**
   - Local cache with `cached_network_image`
   - Firebase Storage for cloud persistence
   - Image cropping available in cat profile editing

## Development Workflow

1. Always test on both iOS and Android
2. Verify Firebase sync works offline and online
3. Test notifications on physical devices (simulators have limitations)
4. Check widget updates after data changes
5. Verify multi-language support for new strings
6. Run `flutter pub get` after pulling changes
7. Clean build if encountering native code issues: `flutter clean && flutter pub get`

## Deployment Checklist

- [ ] Update version in `pubspec.yaml`
- [ ] Test on physical iOS and Android devices
- [ ] Verify Firebase production configuration
- [ ] Check Firestore and Storage security rules
- [ ] Test all authentication methods
- [ ] Verify notifications work
- [ ] Test home widgets on both platforms
- [ ] Check all localizations
- [ ] Build release APK/IPA
- [ ] Test release builds on devices

## Troubleshooting

### Common Issues

1. **Build failures after pulling:** Run `flutter clean && flutter pub get`
2. **iOS pod install issues:** `cd ios && pod install --repo-update`
3. **Firebase not initialized:** Check GoogleService-Info.plist/google-services.json placement
4. **Notifications not working:** Request permissions, test on physical device
5. **Widget not updating:** Verify WidgetService is called after data changes

## Resources

- Flutter Docs: https://docs.flutter.dev
- Firebase Docs: https://firebase.google.com/docs
- Riverpod Docs: https://riverpod.dev
