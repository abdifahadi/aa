# Media Upload Troubleshooting Guide

## What's Happening
Your app is failing to upload media files to Firebase Storage. The error "Error uploading media. Try again or check your connection" indicates a problem with either:
- Firebase Storage configuration
- App permissions
- File handling issues
- Network or firewall issues

## Step 1: Check Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click on "Storage" in the left menu
4. Make sure Storage is enabled
5. Check if there are any files in the storage bucket
6. Note any error messages or warnings

## Step 2: Verify Firebase Storage Rules
1. Deploy the simplified storage rules we created:
   ```bash
   firebase deploy --only storage
   ```
2. This sets relaxed permissions for testing: any authenticated user can upload/download files

## Step 3: Check App Permissions
Ensure your app has proper permissions in the manifest files:

### Android:
Make sure these permissions are in your `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS:
Check that your `Info.plist` has camera and photo library permissions:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos and videos for chat</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to send images in chat</string>
```

## Step 4: Test With a Small Image
1. Try sending a very small image first (under 100KB)
2. Check console logs for error details
3. If small images work but large ones don't, it might be a timeout or size limit issue

## Step 5: Verify Firebase Configuration
1. Make sure your Firebase configuration is correct
2. Check if the same Firebase project is configured in both app and Firebase CLI
3. Run this command to list your Firebase projects:
   ```bash
   firebase projects:list
   ```
4. Ensure the active project matches your app's configuration

## Step 6: File Content and Path Issues
1. Try sending images from different sources (camera vs gallery)
2. Check if the file path contains any special characters
3. Try sending different file types (JPG vs PNG)

## Step 7: Network and Firewall Issues
1. Test uploading on different networks (WiFi vs mobile data)
2. Some networks block certain types of uploads
3. Check if a VPN or firewall might be blocking the connection

## Step 8: Check Console Logs
The enhanced logging we added will provide detailed error information in the console. Look for these messages:
- "ERROR: Test upload failed" - Indicates problems connecting to Firebase Storage
- "ERROR: Firebase Storage permission denied" - Rules issues
- "ERROR: Unauthorized access" or "ERROR: User not authenticated" - Authentication problems

## Step 9: Try a Different Approach
If direct file uploads still fail:
1. Try using a smaller file size or different format
2. Consider implementing a cloud function that generates upload URLs
3. Try using a different storage service temporarily for testing

## Advanced: Getting Technical Error Details
Look for these specific Firebase error codes in logs:
- "storage/unauthorized": Authentication issues
- "storage/quota-exceeded": Storage limit reached
- "storage/invalid-argument": Problem with the file
- "storage/unknown": General Firebase Storage error

## Need More Help?
If you're still experiencing issues after trying these steps, please provide:
1. Any error messages from the console logs
2. Your Firebase project ID
3. What types of files you're trying to upload and their sizes
4. Any patterns you've noticed (e.g., works on WiFi but not mobile data)

This will help identify the specific issue with your media uploads. 