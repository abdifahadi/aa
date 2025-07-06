# Firebase Cloud Functions Setup for Notifications

To fully implement server-side notifications for Abdi Wave Chat, you'll need to set up Firebase Cloud Functions. This document provides guidance on how to implement this functionality.

## Prerequisites

1. Firebase CLI installed
2. A Firebase project with Blaze (pay-as-you-go) plan enabled
3. Node.js installed

## Setup Steps

1. Initialize Firebase Cloud Functions in your project:
```bash
firebase init functions
```

2. Navigate to the functions directory:
```bash
cd functions
```

3. Install necessary dependencies:
```bash
npm install firebase-admin firebase-functions
```

4. Create a file named `index.js` with the following content:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send notification when a new message is added to the global chat
exports.onNewGlobalMessage = functions.firestore
  .document('global_messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const { userId } = messageData;
      
      // Don't send notifications to the message author
      const tokens = await getEligibleFCMTokens(userId);
      
      if (tokens.length === 0) {
        console.log('No eligible tokens found to send notifications');
        return null;
      }
      
      const payload = {
        notification: {
          title: 'New Message in Global Chat',
          body: messageData.text.substring(0, 100), // Limit the preview
          sound: 'default',
        },
        data: {
          type: 'global',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          messageId: context.params.messageId,
        },
      };
      
      // Send notifications to all tokens
      return admin.messaging().sendMulticast({
        tokens,
        notification: payload.notification,
        data: payload.data,
      });
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

// Send notification when a new private message is added
exports.onNewPrivateMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const messageData = snapshot.data();
      const { senderId, receiverId } = messageData;
      
      // Get chat document to get participants
      const chatDoc = await admin.firestore()
        .collection('chats')
        .doc(context.params.chatId)
        .get();
      
      if (!chatDoc.exists) {
        console.log('Chat document not found');
        return null;
      }
      
      const chatData = chatDoc.data();
      
      // Get the recipient user info
      const recipientId = chatData.participants.find(id => id !== senderId);
      if (!recipientId) {
        console.log('Recipient not found');
        return null;
      }
      
      // Get the recipient's FCM tokens
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();
      
      if (!userDoc.exists) {
        console.log('Recipient user document not found');
        return null;
      }
      
      const userData = userDoc.data();
      const tokens = userData.fcmTokens || [];
      
      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipient');
        return null;
      }
      
      // Get sender details for the notification
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();
      
      const senderName = senderDoc.exists 
        ? senderDoc.data().name || 'Someone'
        : 'Someone';
      
      const payload = {
        notification: {
          title: `Message from ${senderName}`,
          body: messageData.type === 'text' 
            ? messageData.content.substring(0, 100)
            : 'Sent you a message',
          sound: 'default',
        },
        data: {
          type: 'private',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          chatId: context.params.chatId,
          senderId: senderId,
        },
      };
      
      // Send notification to all recipient's tokens
      return admin.messaging().sendMulticast({
        tokens,
        notification: payload.notification,
        data: payload.data,
      });
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

// Helper function to get all FCM tokens except for the specified user
async function getEligibleFCMTokens(excludeUserId) {
  try {
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .get();
      
    let tokens = [];
    usersSnapshot.forEach(doc => {
      // Skip the message author
      if (doc.id === excludeUserId) {
        return;
      }
      
      const userData = doc.data();
      
      // Skip users who have disabled global notifications
      if (userData.settings?.notifications?.globalMessages === false) {
        return;
      }
      
      // Get user's FCM tokens
      const userTokens = userData.fcmTokens || [];
      tokens = [...tokens, ...userTokens];
    });
    
    return tokens;
  } catch (error) {
    console.error('Error getting eligible FCM tokens:', error);
    return [];
  }
}
```

5. Deploy the functions to Firebase:
```bash
firebase deploy --only functions
```

## Integration with Flutter

The Flutter app has already been configured to:

1. Handle incoming notifications
2. Store FCM tokens in Firestore
3. Manage notification settings

With these Cloud Functions in place, your app will now be able to send real-time notifications for both global and private messages.

## Testing

Test your implementation by:

1. Send a message in the global chat from one device
2. Check if other devices receive a notification
3. Send a private message from one user to another
4. Verify that the recipient receives a notification

## Troubleshooting

- Check the Firebase Functions logs in the Firebase Console
- Verify that FCM tokens are being properly saved to Firestore
- Ensure all users have notification permissions enabled
- Check that users haven't disabled notifications in their device settings 