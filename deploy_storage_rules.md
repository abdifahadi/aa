# Firebase Storage Rules Deployment Guide

Follow these steps to deploy the provided Firebase Storage rules to your project. This will fix the issue where photos and videos are not showing up in chats.

## 1. Install Firebase CLI (if not already installed)

```bash
npm install -g firebase-tools
```

## 2. Login to Firebase

```bash
firebase login
```

## 3. Select your Firebase project

```bash
firebase use --add
```

Follow the prompts to select your project.

## 4. Deploy the storage rules

```bash
firebase deploy --only storage
```

## Explanation of the Rules

The storage rules in `firebase.storage.rules` ensure that:

1. Users can upload media files to global chat and private chats they're part of
2. Only participants can access private chat media
3. The file naming convention requires the uploader's UID to be part of the filename for security
4. All authenticated users can access global chat media

## Important Debugging Steps

If media files are still not working after applying these rules:

1. Verify Firebase Storage is properly enabled in your project on the Firebase console
2. Check that the same Firebase project is used in both your app and the CLI
3. Ensure your app has internet connectivity and proper permissions
4. Look for error messages in the app's console/logs
5. Check that the Firebase Storage URLs are properly structured and accessible

This should fix the issue with photos and videos not being sent or displayed in chats. 