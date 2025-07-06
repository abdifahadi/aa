// Test script for Agora token generation
const { RtcTokenBuilder, RtcRole } = require('agora-token');

// Agora App ID and Certificate
const appID = 'b7487b8a48da4f89a4285c92e454a96f';
const appCertificate = '3305146df1a942e5ae0c164506e16007';

// Test parameters
const channelName = 'test_channel';
const uid = 12345;
const role = RtcRole.PUBLISHER;
const expirationTimeInSeconds = 3600;

// Calculate privilege expire time
const currentTimestamp = Math.floor(Date.now() / 1000);
const privilegeExpireTime = currentTimestamp + expirationTimeInSeconds;

// Build the token
const token = RtcTokenBuilder.buildTokenWithUid(
  appID,
  appCertificate,
  channelName,
  uid,
  role,
  privilegeExpireTime
);

console.log('Token generated successfully:');
console.log('------------------------------');
console.log('Channel: ' + channelName);
console.log('UID: ' + uid);
console.log('Role: ' + (role === RtcRole.PUBLISHER ? 'Publisher' : 'Subscriber'));
console.log('Expires in: ' + expirationTimeInSeconds + ' seconds');
console.log('------------------------------');
console.log('Token:');
console.log(token);
console.log('------------------------------');
