# Firebase Storage Initialization Guide

## Problem: "object-not-found" Error

If you're seeing the error `[firebase_storage/object-not-found] No object exists at the desired reference` when trying to upload files, this typically means **Firebase Storage hasn't been properly initialized** in your Firebase project.

## Solution: Initialize Firebase Storage

### Step 1: Go to Firebase Console
Open your browser and go to [Firebase Console](https://console.firebase.google.com/) and select your project.

### Step 2: Find Storage in the Menu
In the left sidebar menu, click on "Storage".

### Step 3: Set Up Storage
If Storage hasn't been initialized yet, you'll see a "Get Started" button. Click it.

### Step 4: Choose Security Rules
You'll be asked to choose security rules. For now, select "Start in production mode" and click "Next".

### Step 5: Choose Storage Location
Select a location for your Storage bucket that's closest to your users, then click "Done".

### Step 6: Deploy the Emergency Rules
After Storage is initialized, deploy the emergency rules from the `emergency_storage_rules.txt` file:

```bash
firebase deploy --only storage
```

## Additional Troubleshooting

### Check Your Firebase Config
Make sure the Firebase configuration in your app matches the project you just set up. In your app, you can add this code temporarily to see your config:

```dart
final FirebaseApp app = Firebase.app();
print('Firebase App Name: ${app.name}');
print('Firebase Options: ${app.options.projectId}');
```

### Clear App Data
Sometimes clearing the app data on your device can help if there are cached credentials or settings causing issues.

### Test with a Simple File First
First test with a very small text file before trying to upload images or videos.

### After It Works
Once file uploads are working, remember to replace the emergency rules with more secure ones that only allow authenticated users to upload files. 