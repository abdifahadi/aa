// Test script to simulate the callable function
const { RtcTokenBuilder, RtcRole } = require('agora-token');

// Agora App ID and Certificate
const appID = 'b7487b8a48da4f89a4285c92e454a96f';
const appCertificate = '3305146df1a942e5ae0c164506e16007';

// Simulate the callable function
function generateAgoraToken(data, context) {
  try {
    // Validate required parameters
    const { channelName, uid, role = 'publisher', expirationTimeInSeconds = 3600 } = data;
    
    if (!channelName) {
      throw new Error('Channel name is required.');
    }

    if (!uid) {
      throw new Error('User ID is required.');
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

    console.log('Token generated for channel: ' + channelName + ', uid: ' + uid + ', role: ' + role);

    // Return the token
    return { token };
  } catch (error) {
    console.error('Error generating Agora token:', error);
    throw new Error('Failed to generate token: ' + error.message);
  }
}

// Test the function with the same parameters as in the Flutter app
const testData = {
  channelName: 'test_channel',
  uid: '12345',
  role: 'publisher',
};

try {
  const result = generateAgoraToken(testData, { auth: { uid: 'test-user' } });
  
  console.log('Callable function test result:');
  console.log('------------------------------');
  console.log('Channel:', testData.channelName);
  console.log('UID:', testData.uid);
  console.log('Role:', testData.role);
  console.log('------------------------------');
  console.log('Token:');
  console.log(result.token);
  console.log('------------------------------');
  
  console.log('This token would be returned to the Flutter app when deployed.');
} catch (error) {
  console.error('Test failed:', error);
}
