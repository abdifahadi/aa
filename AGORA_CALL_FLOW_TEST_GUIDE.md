# Agora Calling Flow Test Guide

This guide explains how to test and validate the complete Agora calling flow between two users.

## Overview

The Agora calling system has been fixed to address several issues:

1. Numeric UID generation inconsistency between caller and receiver
2. Engine reference problems in the CallScreen
3. Improper channel media options configuration
4. Error handling and retry logic issues

The test utilities in this app will help you validate that the fixes are working correctly.

## Testing Tools

We've created several tools to help test the Agora calling flow:

1. **Agora Call Flow Test** - A comprehensive test that validates the complete calling flow from token generation to call connection.
2. **Agora Call Verification** - A tool to verify call connections between users.
3. **Agora Connection Diagnostic** - A detailed diagnostic tool for connection issues.
4. **Agora Token Test** - A tool specifically for testing token generation.

## How to Test

### Method 1: Using the Agora Call Flow Test

1. Open the app and access the Developer Menu (tap the app title 5 times or use the developer mode button in debug builds)
2. Select "Agora Call Flow Test"
3. Enter a valid user ID and name for the receiver
4. Select the call type (audio or video)
5. Tap "Run Test"
6. The test will validate:
   - Permissions
   - Token generation
   - Call creation
   - Caller connection
   - Receiver connection
   - Audio/video streams
   - Call termination

### Method 2: Real User Testing

1. Log in with two different user accounts on two different devices
2. On device A, initiate a call to device B
3. On device B, accept the call
4. Verify that:
   - Both users can see each other (for video calls)
   - Both users can hear each other
   - The call maintains a stable connection
   - Call controls (mute, speaker, video toggle) work correctly
   - Call can be ended by either party

## Troubleshooting

If you encounter issues during testing:

1. Check the logs in the Agora Call Flow Test for specific error messages
2. Verify that both devices have granted microphone and camera permissions
3. Ensure both devices have a stable internet connection
4. Check that the Agora App ID and certificate are correctly configured
5. Verify that the token generation service is working correctly

## Common Issues and Solutions

1. **Call fails to connect**
   - Check token generation and UID consistency
   - Verify channel name is consistent between caller and receiver
   - Ensure both users have the necessary permissions

2. **Audio/video not working**
   - Check if the device has granted the necessary permissions
   - Verify that audio/video is not muted
   - Check if the device has hardware issues

3. **Call drops frequently**
   - Check network connectivity
   - Verify that the app has proper background processing permissions
   - Check for device-specific issues (battery optimization, etc.)

## Validation Checklist

- [ ] Token generation works correctly
- [ ] Call initialization succeeds
- [ ] Caller can connect to the channel
- [ ] Receiver can connect to the channel
- [ ] Audio works in both directions
- [ ] Video works in both directions (for video calls)
- [ ] Call controls function correctly
- [ ] Call can be terminated properly

## Reporting Issues

If you discover issues during testing, please document:

1. The specific step that failed
2. Any error messages displayed
3. The device and OS version
4. Network conditions (WiFi, cellular, etc.)
5. Steps to reproduce the issue

This information will help us further improve the calling system. 