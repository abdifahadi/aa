# Firebase Cloud Functions Deployment Instructions

Follow these steps to deploy your Firebase Cloud Functions so that message notifications will work properly:

## Prerequisites

1. Install Node.js and npm if you haven't already (https://nodejs.org/)
2. Install Firebase CLI globally:
   ```
   npm install -g firebase-tools
   ```
3. Make sure you have a Firebase account and project set up

## Deployment Steps

1. Log in to Firebase from the terminal:
   ```
   firebase login
   ```

2. Navigate to the `lib/cloud_functions` directory in your project:
   ```
   cd lib/cloud_functions
   ```

3. Initialize Firebase Functions in this directory (if you haven't already):
   ```
   firebase init functions
   ```
   - Select your Firebase project
   - Choose JavaScript as the language
   - Say yes to ESLint
   - Say yes to installing dependencies

4. Copy the notification code from `notification_functions.js` to the new `functions/index.js` file that was created

5. Deploy your functions:
   ```
   firebase deploy --only functions
   ```

6. Verify that the function was deployed successfully by checking the Firebase console under "Functions"

## Testing Notifications

1. Launch your app on two different devices (or emulators)
2. Sign in with different accounts on each device
3. Send a message from one device to another
4. Verify that the notification appears with the sender's name

## Troubleshooting

If notifications aren't showing:

1. Check the Firebase Functions logs for errors in the Firebase console
2. Ensure FCM tokens are being saved to Firestore by checking your user documents
3. Verify that the app has notification permissions on the device
4. Test with the app in both foreground and background states

### Android-specific

For Android, make sure:
1. You have the correct Firebase configuration in `android/app/google-services.json`
2. Your app's manifest has all the required permissions:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.VIBRATE"/>
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   ```

### Icon Setup

To show your app icon in notifications:
1. Place a notification icon (PNG) in `android/app/src/main/res/drawable/notification_icon.png`
2. Make sure this file is referenced correctly in the cloud function

## Summary

Once deployed correctly, when someone sends a message:
- If the app is open (foreground), the notification will be shown within the app
- If the app is closed or minimized (background/terminated), you'll see who sent the message in the phone's notification bar

The notification will show:
1. The sender's name as the notification title
2. The message text as the notification body 