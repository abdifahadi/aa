const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { RtcTokenBuilder, RtcRole } = require('agora-token');

admin.initializeApp();

// Agora App ID and Certificate
const appID = 'b7487b8a48da4f89a4285c92e454a96f';
// IMPORTANT: Replace with your actual App Certificate from Agora Console
const appCertificate = '3305146df1a942e5ae0c164506e16007';

/**
 * Callable function to generate Agora RTC token
 * Required parameters:
 * - channelName: string - Name of the channel to join
 * - uid: string - User ID (can be stringified number)
 * - role: string - Role ("publisher" or "subscriber")
 * - expirationTimeInSeconds: number - Token expiration time in seconds (default: 3600)
 */
exports.generateAgoraToken = functions.https.onCall(async (data, context) => {
  try {
    // Ensure user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'The function must be called while authenticated.'
      );
    }

    // Validate required parameters
    const { channelName, uid, role = 'publisher', expirationTimeInSeconds = 3600 } = data;
    
    if (!channelName) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Channel name is required.'
      );
    }

    if (!uid) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'User ID is required.'
      );
    }

    // Convert string uid to number if needed for Agora
    const uidNumber = parseInt(uid, 10) || 0;

    // Determine the role
    const rtcRole = role === 'publisher' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

    // Calculate privilege expire time
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpireTime = currentTimestamp + expirationTimeInSeconds;

    // Build the token
    const token = RtcTokenBuilder.buildTokenWithUid(
      appID,
      appCertificate,
      channelName,
      uidNumber,
      rtcRole,
      privilegeExpireTime
    );

    console.log(`Token generated for channel: ${channelName}, uid: ${uid}, role: ${role}`);

    // Log token generation (but don't log the actual token for security)
    functions.logger.info(
      `Generated Agora token for user ${context.auth.uid}, channel: ${channelName}`,
      { uid: uid, channelName: channelName, role: role }
    );

    // Return the token
    return { token };
  } catch (error) {
    console.error('Error generating Agora token:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to generate token: ${error.message}`
    );
  }
});

/**
 * Cloud Function triggered when a new call is created in Firestore
 * Sends a notification to the receiver's device(s)
 */
exports.sendCallNotification = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snapshot, context) => {
    try {
      const callData = snapshot.data();
      const { callerId, callerName, callerPhotoUrl, receiverId, type, channelId, token } = callData;
      
      // Skip if essential data is missing
      if (!callerId || !receiverId || !channelId) {
        console.log('Missing essential call data');
        return null;
      }
      
      // Get the receiver's FCM tokens
      const receiverDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();
      
      if (!receiverDoc.exists) {
        console.log('Receiver not found:', receiverId);
        return null;
      }
      
      const receiverData = receiverDoc.data();
      const fcmTokens = receiverData.fcmTokens || [];
      
      if (fcmTokens.length === 0) {
        console.log('Receiver has no FCM tokens:', receiverId);
        return null;
      }
      
      // Create notification payload
      const payload = {
        notification: {
          title: `Incoming ${type === 'video' ? 'Video' : 'Voice'} Call`,
          body: `${callerName || 'Someone'} is calling you`,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          sound: 'default', // Use default sound for notification
        },
        data: {
          type: 'call',
          callId: context.params.callId,
          callerId: callerId,
          callerName: callerName || 'Unknown',
          callerPhotoUrl: callerPhotoUrl || '',
          callType: type || 'audio',
          channelId: channelId,
          token: token || '',
          timestamp: new Date().getTime().toString(),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'abdi_wave_calls',
            icon: 'notification_icon',
            priority: 'high',
            sound: 'default',
            // Use full screen intent for calls
            visibility: 'public',
          },
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true,
              sound: 'default',
              // Use critical alerts for calls
              category: 'call',
            },
          },
        },
      };
      
      console.log(`Sending call notification to user: ${receiverId}`);
      
      // Send notification to all tokens
      const result = await admin.messaging().sendMulticast({
        tokens: fcmTokens,
        notification: payload.notification,
        data: payload.data,
        android: payload.android,
        apns: payload.apns,
      });
      
      console.log(`Successfully sent ${result.successCount} call notifications, failed: ${result.failureCount}`);
      
      return null;
    } catch (error) {
      console.error('Error sending call notification:', error);
      return null;
    }
  });

// Update call status when a call is updated
exports.handleCallStatusUpdate = functions.firestore
  .document('calls/{callId}')
  .onUpdate(async (change, context) => {
    try {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      
      // If status hasn't changed, do nothing
      if (beforeData.status === afterData.status) {
        return null;
      }
      
      const { callerId, receiverId, status } = afterData;
      
      // If call was missed, rejected, or ended, send notification to caller
      if (['missed', 'rejected', 'ended'].includes(status)) {
        // Get caller's FCM tokens
        const callerDoc = await admin.firestore()
          .collection('users')
          .doc(callerId)
          .get();
        
        if (!callerDoc.exists) {
          console.log('Caller not found:', callerId);
          return null;
        }
        
        const callerData = callerDoc.data();
        const fcmTokens = callerData.fcmTokens || [];
        
        if (fcmTokens.length === 0) {
          console.log('Caller has no FCM tokens:', callerId);
          return null;
        }
        
        // Create notification payload for call status update
        const payload = {
          data: {
            type: 'call_update',
            callId: context.params.callId,
            status: status,
            timestamp: new Date().getTime().toString(),
          },
        };
        
        // Send silent notification to caller
        await admin.messaging().sendMulticast({
          tokens: fcmTokens,
          data: payload.data,
        });
        
        console.log(`Sent call status update to caller: ${callerId}, status: ${status}`);
      }
      
      return null;
    } catch (error) {
      console.error('Error handling call status update:', error);
      return null;
    }
  });