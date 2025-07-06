const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function triggered when a new message is created in Firestore
 * Sends a notification to the user's device(s)
 */
exports.sendChatNotification = functions.firestore
  .document('messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      // Get the message data
      const messageData = snapshot.data();
      
      // Don't send notification if there's no message text or sender info
      if (!messageData || !messageData.text || !messageData.userId) {
        console.log('Notification skipped: Missing required message data');
        return null;
      }
      
      // Get the sender's user data to include their name
      const senderSnapshot = await admin.firestore()
        .collection('users')
        .doc(messageData.userId)
        .get();
      
      if (!senderSnapshot.exists) {
        console.log(`Notification skipped: Sender ${messageData.userId} not found`);
        return null;
      }
      
      const senderData = senderSnapshot.data();
      const senderName = senderData.displayName || 'Someone';
      
      // Get the recipient's user ID
      const recipientId = messageData.chatId.replace(messageData.userId, '').replace('_', '');
      
      // Get the recipient's FCM tokens
      const recipientSnapshot = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();
      
      if (!recipientSnapshot.exists) {
        console.log(`Notification skipped: Recipient ${recipientId} not found`);
        return null;
      }
      
      const recipientData = recipientSnapshot.data();
      const tokens = recipientData.fcmTokens || {};
      
      // If there are no tokens, skip sending notification
      if (Object.keys(tokens).length === 0) {
        console.log(`Notification skipped: No FCM tokens for ${recipientId}`);
        return null;
      }
      
      // Prepare notification payload
      const payload = {
        notification: {
          title: senderName,
          body: messageData.text,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        data: {
          type: 'chat',
          senderId: messageData.userId,
          chatId: messageData.chatId,
          messageId: context.params.messageId,
        },
      };
      
      // Send notification to all recipient's devices
      const tokensArray = Object.values(tokens);
      const response = await admin.messaging().sendToDevice(tokensArray, payload);
      
      console.log(`Notification sent to ${recipientId}: ${response.successCount} successful, ${response.failureCount} failed`);
      
      // Clean up invalid tokens
      const invalidTokens = [];
      response.results.forEach((result, index) => {
        if (result.error) {
          console.log(`Error sending to token: ${result.error.code}`);
          if (
            result.error.code === 'messaging/invalid-registration-token' ||
            result.error.code === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(Object.keys(tokens)[index]);
          }
        }
      });
      
      // Remove invalid tokens from the user's document
      if (invalidTokens.length > 0) {
        const tokenUpdates = {};
        invalidTokens.forEach(token => {
          tokenUpdates[`fcmTokens.${token}`] = admin.firestore.FieldValue.delete();
        });
        
        await admin.firestore()
          .collection('users')
          .doc(recipientId)
          .update(tokenUpdates);
          
        console.log(`Removed ${invalidTokens.length} invalid tokens for user ${recipientId}`);
      }
      
      return null;
    } catch (error) {
      console.error('Error sending chat notification:', error);
      return null;
    }
  });

/**
 * Cloud Function triggered when a new call document is created in Firestore
 * Sends a call notification to the recipient's device(s)
 */
exports.sendCallNotification = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snapshot, context) => {
    try {
      // Get the call data
      const callData = snapshot.data();
      
      // Don't send notification if this isn't a new ringing call
      if (!callData || callData.status !== 'ringing') {
        console.log('Call notification skipped: Not a new ringing call');
        return null;
      }
      
      // Get the recipient's FCM tokens
      const recipientSnapshot = await admin.firestore()
        .collection('users')
        .doc(callData.receiverId)
        .get();
      
      if (!recipientSnapshot.exists) {
        console.log(`Call notification skipped: Recipient ${callData.receiverId} not found`);
        return null;
      }
      
      const recipientData = recipientSnapshot.data();
      const tokens = recipientData.fcmTokens || {};
      
      // If there are no tokens, skip sending notification
      if (Object.keys(tokens).length === 0) {
        console.log(`Call notification skipped: No FCM tokens for ${callData.receiverId}`);
        return null;
      }
      
      // Prepare notification payload
        const payload = {
          notification: {
          title: `${callData.callerName} is calling you`,
          body: `Incoming ${callData.type} call`,
            sound: 'default',
          priority: 'high',
          },
          data: {
          type: 'call',
          callId: context.params.callId,
          callerId: callData.callerId,
          callerName: callData.callerName,
          callerPhotoUrl: callData.callerPhotoUrl || '',
          receiverId: callData.receiverId,
          receiverName: callData.receiverName || '',
          receiverPhotoUrl: callData.receiverPhotoUrl || '',
          channelId: callData.channelId,
          token: callData.token,
          callType: callData.type,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          android: {
            priority: 'high',
            notification: {
            sound: 'default',
              priority: 'high',
            channelId: 'calls',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              category: 'call',
              contentAvailable: true,
            },
            },
          },
        };

      // Send notification to all recipient's devices
      const tokensArray = Object.values(tokens);
      const response = await admin.messaging().sendToDevice(tokensArray, payload);
      
      console.log(`Call notification sent to ${callData.receiverId}: ${response.successCount} successful, ${response.failureCount} failed`);
      
      // Clean up invalid tokens
      const invalidTokens = [];
      response.results.forEach((result, index) => {
        if (result.error) {
          console.log(`Error sending to token: ${result.error.code}`);
          if (
            result.error.code === 'messaging/invalid-registration-token' ||
            result.error.code === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(Object.keys(tokens)[index]);
          }
        }
      });
      
      // Remove invalid tokens from the user's document
      if (invalidTokens.length > 0) {
        const tokenUpdates = {};
        invalidTokens.forEach(token => {
          tokenUpdates[`fcmTokens.${token}`] = admin.firestore.FieldValue.delete();
        });
        
        await admin.firestore()
          .collection('users')
          .doc(callData.receiverId)
          .update(tokenUpdates);
          
        console.log(`Removed ${invalidTokens.length} invalid tokens for user ${callData.receiverId}`);
      }
      
      // Set up a timer to automatically update the call status to "missed" after 30 seconds
      // if it's still in "ringing" state
      setTimeout(async () => {
        try {
          const callRef = admin.firestore().collection('calls').doc(context.params.callId);
          const callSnapshot = await callRef.get();
          
          if (callSnapshot.exists && callSnapshot.data().status === 'ringing') {
            await callRef.update({
              status: 'missed',
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`Call ${context.params.callId} automatically marked as missed after timeout`);
          }
        } catch (error) {
          console.error('Error in call timeout handler:', error);
        }
      }, 30000); // 30 seconds timeout
      
      return null;
    } catch (error) {
      console.error('Error sending call notification:', error);
      return null;
    }
  });

/**
 * Cloud Function triggered when a call document is updated in Firestore
 * Handles call status changes
 */
exports.handleCallStatusChange = functions.firestore
  .document('calls/{callId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      
      // Skip if status didn't change
      if (beforeData.status === afterData.status) {
        return null;
      }
      
      console.log(`Call ${context.params.callId} status changed: ${beforeData.status} -> ${afterData.status}`);
      
      // Handle specific status transitions as needed
      // For example, you could send additional notifications for missed calls
      
      return null;
    } catch (error) {
      console.error('Error handling call status change:', error);
      return null;
    }
  });

// Send notification when a new private message is added to a chat
exports.sendPrivateMessageNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    try {
      const message = snapshot.data();
      const { senderId, content, type, senderName, senderEmail, mediaUrl, timestamp } = message;
      const { chatId, messageId } = context.params;
      
      // Get the chat document to find participants
      const chatDoc = await admin.firestore()
        .collection('chats')
        .doc(chatId)
        .get();
      
      if (!chatDoc.exists) {
        console.log('Chat not found:', chatId);
        return null;
      }
      
      const chatData = chatDoc.data();
      
      // Find the recipient (the user who is not the sender)
      const recipientId = chatData.participants.find(uid => uid !== senderId);
      
      if (!recipientId) {
        console.log('Recipient not found in chat:', chatId);
        return null;
      }
      
      // Get recipient user data
      const recipientDoc = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();
      
      if (!recipientDoc.exists) {
        console.log('Recipient user not found:', recipientId);
        return null;
      }
      
      // Get recipient's notification settings
      const settingsDoc = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .collection('settings')
        .doc('notifications')
        .get();
      
      // Check if user has disabled private message notifications
      if (settingsDoc.exists && settingsDoc.data().privateMessages === false) {
        console.log(`User ${recipientId} has disabled private message notifications`);
        return null;
      }
      
      // Check if chat is muted
      const isMuted = chatData.muted && chatData.muted[recipientId] === true;
      
      // Get sender's information for the notification
      let senderDisplayName = senderName || 'Someone';
      if (!senderName) {
        const senderDoc = await admin.firestore()
          .collection('users')
          .doc(senderId)
          .get();
        
        if (senderDoc.exists && senderDoc.data().name) {
          senderDisplayName = senderDoc.data().name;
        }
      }
      
      // Get sender's photo URL for rich notifications
      let senderPhotoUrl = '';
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();
      
      if (senderDoc.exists && senderDoc.data().photoUrl) {
        senderPhotoUrl = senderDoc.data().photoUrl;
      }
        
      // Get recipient's FCM tokens
      const recipientData = recipientDoc.data();
      const tokens = Object.keys(recipientData.fcmTokens || {}).filter(key => recipientData.fcmTokens[key] === true);
      
      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipient:', recipientId);
        return null;
      }
      
      // Check if the recipient is currently viewing this chat
      // We can do this by checking the lastActive field in the chat document
      const isRecipientActive = chatData.lastActive && 
                               chatData.lastActive[recipientId] && 
                               Date.now() - chatData.lastActive[recipientId]._seconds * 1000 < 30000; // 30 seconds
      
      if (isRecipientActive) {
        console.log(`Recipient ${recipientId} is currently active in chat, skipping notification`);
        return null;
      }
      
      // Get message preview based on type
      let messagePreview = content;
      if (type === 'image') {
        messagePreview = '📷 Photo';
      } else if (type === 'video') {
        messagePreview = '🎥 Video';
      } else if (type === 'document') {
        messagePreview = '📄 Document';
      } else if (content.length > 100) {
        messagePreview = `${content.substring(0, 97)}...`;
      }
      
      // Create notification payload with proper sender information
      const payload = {
        notification: {
          title: senderDisplayName,
          body: messagePreview,
          sound: isMuted ? '' : 'default',
          badge: '1',
          // Image for rich notifications (if available)
          imageUrl: type === 'image' ? mediaUrl : undefined,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          type: 'chat',
          chatId: chatId,
          messageId: messageId,
          senderId: senderId,
          senderName: senderDisplayName,
          senderEmail: senderEmail || '',
          content: content,
          messageType: type,
          timestamp: timestamp ? timestamp.toDate().getTime().toString() : Date.now().toString(),
          senderPhotoUrl: senderPhotoUrl || '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'messages',
            sound: isMuted ? null : 'default',
            priority: 'high',
            visibility: 'private',
            // For notification grouping
            tag: `chat_${chatId}`,
          },
          // For notification grouping
          collapseKey: `chat_${chatId}`,
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: senderDisplayName,
                body: messagePreview,
              },
              badge: 1,
              sound: isMuted ? null : 'default',
              // For notification grouping
              'thread-id': `chat_${chatId}`,
              'content-available': 1,
              'mutable-content': 1,
            },
            // Custom data for iOS
            senderId: senderId,
            chatId: chatId,
            messageId: messageId,
            messageType: type,
          },
        },
      };
      
      // Check if we need to update the notification count in the chat document
      let unreadCountUpdate = {};
      if (chatData.unreadCount && chatData.unreadCount[recipientId]) {
        unreadCountUpdate = {
          [`unreadCount.${recipientId}`]: admin.firestore.FieldValue.increment(1)
        };
      } else {
        unreadCountUpdate = {
          [`unreadCount.${recipientId}`]: 1
        };
      }
      
      // Update the unread count in the chat document
      await admin.firestore()
        .collection('chats')
        .doc(chatId)
        .update(unreadCountUpdate);
      
      // Send notification to recipient's devices
      const response = await admin.messaging().sendMulticast({
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      
      console.log(`Sent notification to ${response.successCount} of ${tokens.length} devices for recipient ${recipientId}`);
      
      // Handle failed tokens
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
          }
        });
        
        // Remove failed tokens
        if (failedTokens.length > 0) {
          const tokenUpdates = {};
          failedTokens.forEach(token => {
            tokenUpdates[`fcmTokens.${token}`] = admin.firestore.FieldValue.delete();
          });
          
          await admin.firestore()
            .collection('users')
            .doc(recipientId)
            .update(tokenUpdates);
            
          console.log(`Removed ${failedTokens.length} invalid tokens for user ${recipientId}`);
        }
      }
      
      return { success: true, notificationsSent: response.successCount };
      
    } catch (error) {
      console.error('Error sending private message notification:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * Cloud Function to send call notifications
 * This can be called directly from the client using Firebase Functions
 */
exports.sendCallNotification = functions.https.onCall(async (data, context) => {
  try {
    // Ensure the user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be signed in to make this request.'
      );
    }
    
    const { receiverId, callData } = data;
    
    if (!receiverId || !callData || !callData.callId || !callData.channelId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required call data'
      );
    }
    
    // Get recipient user document to get FCM tokens
    const recipientDoc = await admin.firestore()
      .collection('users')
      .doc(receiverId)
      .get();
      
    if (!recipientDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Recipient user not found'
      );
    }
    
    // Get FCM tokens
    const recipientData = recipientDoc.data();
    const tokens = recipientData.fcmTokens || [];
    
    if (tokens.length === 0) {
      console.log('No FCM tokens found for recipient:', receiverId);
      return { success: false, reason: 'no_tokens' };
    }
    
    // Create notification payload
    const payload = {
      notification: {
        title: `Incoming ${callData.callType === 'video' ? 'Video' : 'Audio'} Call`,
        body: `${callData.callerName} is calling you`,
        sound: 'ringtone',
        channelId: 'calls',
        priority: 'high',
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        type: 'call',
        callId: callData.callId,
        callerId: callData.callerId,
        callerName: callData.callerName,
        callerPhotoUrl: callData.callerPhotoUrl || '',
        callType: callData.callType,
        channelId: callData.channelId,
        token: callData.token,
        timestamp: Date.now().toString(),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'calls',
          priority: 'high',
          sound: 'ringtone',
          visibility: 'public',
          vibrateTimingsMillis: [0, 500, 500, 500],
          // Full screen intent for incoming calls
          notification_priority: 'PRIORITY_MAX',
          default_vibrate_timings: true,
          default_sound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            sound: 'ringtone.mp3',
            badge: 1,
            category: 'INCOMING_CALL',
          },
        },
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
      },
    };
    
    // Send high-priority notification to all recipient tokens
    const response = await admin.messaging().sendMulticast({
      tokens,
      notification: payload.notification,
      data: payload.data,
      android: payload.android,
      apns: payload.apns,
    });
    
    console.log(`Sent call notification to ${response.successCount} of ${tokens.length} devices for recipient ${receiverId}`);
    
    // Update call document to indicate notification was sent
    await admin.firestore()
      .collection('calls')
      .doc(callData.callId)
      .update({
        notificationSent: true,
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    return { 
      success: true, 
      notificationsSent: response.successCount,
      tokensCount: tokens.length
    };
    
  } catch (error) {
    console.error('Error sending call notification:', error);
    return { success: false, error: error.message };
  }
});

/**
 * Cloud Function triggered when a new call document is created
 * Automatically sends a notification to the receiver
 */
exports.onNewCallCreated = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snapshot, context) => {
    try {
      const callData = snapshot.data();
      const { callId } = context.params;
      
      // Only process dialing calls
      if (callData.status !== 'dialing') {
        console.log(`Call ${callId} is not in dialing state, skipping notification`);
        return null;
      }
      
      const receiverId = callData.receiverId;
      
      // Get recipient's FCM tokens
      const recipientDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();
        
      if (!recipientDoc.exists) {
        console.log(`Recipient ${receiverId} not found`);
        return null;
      }
      
      const recipientData = recipientDoc.data();
      const tokens = recipientData.fcmTokens || [];
      
      if (tokens.length === 0) {
        console.log(`No FCM tokens found for recipient ${receiverId}`);
        return null;
      }
      
      // Create notification payload
      const payload = {
        notification: {
          title: `Incoming ${callData.type === 'video' ? 'Video' : 'Audio'} Call`,
          body: `${callData.callerName} is calling you`,
          sound: 'ringtone',
          channelId: 'calls',
          priority: 'high',
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          type: 'call',
          callId: callId,
          callerId: callData.callerId,
          callerName: callData.callerName,
          callerPhotoUrl: callData.callerPhotoUrl || '',
          callType: callData.type,
          channelId: callData.channelId,
          token: callData.token,
          timestamp: Date.now().toString(),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'calls',
            priority: 'high',
            sound: 'ringtone',
            visibility: 'public',
            vibrateTimingsMillis: [0, 500, 500, 500],
          },
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true,
              sound: 'ringtone.mp3',
              badge: 1,
              category: 'INCOMING_CALL',
            },
          },
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
        },
      };
      
      // Send notification to all recipient tokens
      const response = await admin.messaging().sendMulticast({
        tokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      
      console.log(`Sent call notification to ${response.successCount} of ${tokens.length} devices for recipient ${receiverId}`);
      
      // Update call document to indicate notification was sent
      await admin.firestore()
        .collection('calls')
        .doc(callId)
        .update({
          notificationSent: true,
          notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      return null;
    } catch (error) {
      console.error('Error sending call notification:', error);
      return null;
    }
  }); 