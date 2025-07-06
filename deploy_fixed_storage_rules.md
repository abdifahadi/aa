# Firebase Storage Rules Deployment

To fix the media upload issues, follow these steps to deploy the simpler storage rules:

## 1. Deploy the simplified storage rules

```bash
firebase deploy --only storage
```

## 2. Test media uploads after deployment

Once the new rules are deployed, try sending photos and videos again. The simplified rules allow any authenticated user to upload media files.

## 3. Check Firebase Storage Console

If you still have issues, go to the Firebase Console > Storage section and check:
- If any files are being uploaded
- If there are any error messages in the Storage section
- If the Storage bucket is properly initialized

## 4. Check your Firebase project settings

Make sure:
- You're using the correct Firebase project in your app
- Storage service is enabled in the Firebase Console
- Your app has internet permission

## Security Note

The current storage.rules file grants read/write access to all authenticated users. Once your app is working correctly, consider implementing more restrictive rules for production use. 

# Fixed Firestore Security Rules

The following security rules fix the issue with call receiving by allowing:
1. Any authenticated user to read/write to the main calls collection
2. Any authenticated user to read/write to any user's calls subcollection (necessary for call creation)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow reading calls in the main collection
    match /calls/{callId} {
      allow read, write: if request.auth != null;
    }

    // Allow reading/writing to user documents
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
      
      // Allow reading/writing to any user's calls subcollection
      match /calls/{callId} {
        allow read, write: if request.auth != null;
      }
    }
    
    // Add other rules for your app below
  }
}
```

## How to Deploy

1. Go to the Firebase Console
2. Select your project
3. Go to Firestore Database
4. Click on "Rules" tab
5. Replace the current rules with the ones above
6. Click "Publish"

## Explanation

The key change is allowing any authenticated user to write to any user's calls subcollection. This is necessary because:

1. When User A calls User B, User A's app needs to create a document in User B's subcollection
2. With the previous rules, this was blocked because User A can only write to their own subcollection

This change maintains security (only authenticated users can write) while enabling the necessary functionality for call receiving. 