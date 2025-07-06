# Abdi Wave Chat

A comprehensive real-time chat application built with Flutter and Firebase.

## Troubleshooting

If you encounter issues running the app, try the following solutions:

### Firebase App Check Error

If you see the error "No AppCheckProvider installed", add Firebase App Check to your project:

1. Add the dependency to pubspec.yaml:
   ```yaml
   dependencies:
     firebase_app_check: ^0.2.1+8
   ```

2. Initialize Firebase App Check in main.dart:
   ```dart
   await FirebaseAppCheck.instance.activate(
     androidProvider: AndroidProvider.debug,
   );
   ```

### Google Sign-In Issues

If you see warnings about clientId on Android:

1. Update the GoogleSignIn configuration in firebase_service.dart to use serverClientId instead of clientId:
   ```dart
   final GoogleSignIn _googleSignIn = GoogleSignIn(
     scopes: [
       'email',
       'https://www.googleapis.com/auth/userinfo.profile',
     ],
     signInOption: SignInOption.standard,
     serverClientId: 'YOUR_SERVER_CLIENT_ID',
     forceCodeForRefreshToken: true,
   );
   ```

### General Troubleshooting Steps

1. Run `flutter clean` to clean the project
2. Run `flutter pub get` to reinstall dependencies
3. Restart your IDE and emulator
4. Check Firebase configuration in google-services.json

## Features

- Google Sign-In authentication
- User profile creation and management
- Global public chat
- Private messaging between users
- Media sharing (images, videos, documents)
- User search functionality
- Real-time message updates
- Message timestamps and sender information
- Tabbed interface for global and private chats
- Video calling using Agora RTC
- Push notifications
- Online/offline status

## Setup Instructions

### Prerequisites

- Flutter SDK (latest stable version)
- Firebase account
- Android Studio or VS Code with Flutter extensions

### Firebase Setup

1. The project is already configured with Firebase. The `google-services.json` file is included in the `android/app` directory.

2. For iOS, you need to:
   - Create a Firebase iOS app in your Firebase console
   - Download the `GoogleService-Info.plist` file
   - Place it in the `ios/Runner` directory
   - Add it to your Xcode project (open `ios/Runner.xcworkspace` in Xcode, right-click on Runner, "Add Files to Runner", and select the downloaded file)

### Running the App

1. Install dependencies:
   ```
   flutter pub get
   ```

2. Run the app:
   ```
   flutter run
   ```

## Project Structure

- `lib/main.dart` - Entry point with Firebase initialization and splash screen
- `lib/screens/chat_app.dart` - Main chat application with all functionality
- `lib/models/` - Data models for users, messages, and chats
- `lib/services/` - Services for Firebase operations and file handling

## Dependencies

- firebase_core, firebase_auth, cloud_firestore, firebase_storage
- google_sign_in
- file_picker, image_picker, path_provider
- cached_network_image
- intl, provider, uuid
- and more

## Usage

1. Sign in with your Google account
2. Complete your profile with name and date of birth
3. Use the Global Chat tab for public messaging
4. Search for users to start private conversations
5. Share text, images, videos, and documents in both chat types
6. Switch between global and private chats using the tabs

## License

This project is for educational purposes only.
