import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/call_service.dart';
import '../services/notification_service.dart';
import '../services/media_cache_service.dart';
import '../utils/agora_call_logger.dart';
import 'test/agora_call_verification.dart';

class DeveloperMenu extends StatefulWidget {
  const DeveloperMenu({Key? key}) : super(key: key);

  @override
  State<DeveloperMenu> createState() => _DeveloperMenuState();
}

class _DeveloperMenuState extends State<DeveloperMenu> {
  final FirebaseService _firebaseService = FirebaseService();
  final CallService _callService = CallService();
  final NotificationService _notificationService = NotificationService();
  
  bool _isLoading = false;
  String _lastAction = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Menu'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Authentication & User'),
          _buildDeveloperOption(
            'Check Current User',
            'Verify current authentication status',
            Icons.person,
            _checkCurrentUser,
          ),
          _buildDeveloperOption(
            'Force Refresh Token',
            'Refresh Firebase authentication token',
            Icons.refresh,
            _refreshToken,
          ),
          const SizedBox(height: 20),
          
          _buildSectionHeader('Call System'),
          _buildDeveloperOption(
            'Test Agora Connection',
            'Verify Agora RTC engine initialization',
            Icons.video_call,
            _testAgoraConnection,
          ),
          _buildDeveloperOption(
            'Open Call Verification',
            'Advanced call system testing',
            Icons.bug_report,
            _openCallVerification,
          ),
          _buildDeveloperOption(
            'Clear Call Logs',
            'Remove all call history and logs',
            Icons.clear_all,
            _clearCallLogs,
          ),
          const SizedBox(height: 20),
          
          _buildSectionHeader('Notifications'),
          _buildDeveloperOption(
            'Test Notification',
            'Send test notification',
            Icons.notifications,
            _testNotification,
          ),
          _buildDeveloperOption(
            'Check FCM Token',
            'Display current FCM registration token',
            Icons.token,
            _checkFCMToken,
          ),
          const SizedBox(height: 20),
          
          _buildSectionHeader('Cache & Storage'),
          _buildDeveloperOption(
            'Clear Media Cache',
            'Remove all cached images and videos',
            Icons.delete_sweep,
            _clearMediaCache,
          ),
          _buildDeveloperOption(
            'Show Cache Size',
            'Display current cache usage',
            Icons.storage,
            _showCacheSize,
          ),
          const SizedBox(height: 20),
          
          _buildSectionHeader('Debug Tools'),
          _buildDeveloperOption(
            'Export Logs',
            'Copy debug logs to clipboard',
            Icons.copy,
            _exportLogs,
          ),
          _buildDeveloperOption(
            'Reset All Settings',
            'Clear all app data and settings',
            Icons.settings_backup_restore,
            _resetAllSettings,
          ),
          
          if (_lastAction.isNotEmpty) ...[
            const SizedBox(height: 20),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last Action Result:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_lastAction),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          _buildWarningCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildDeveloperOption(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: _isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios),
        onTap: _isLoading ? null : onTap,
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Developer Tools',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'These tools are for development and testing purposes only. Use with caution in production.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkCurrentUser() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        setState(() {
          _lastAction = 'Current User: ${user.email} (UID: ${user.uid})';
        });
      } else {
        setState(() {
          _lastAction = 'No user currently signed in';
        });
      }
    } catch (e) {
      setState(() {
        _lastAction = 'Error checking user: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshToken() async {
    setState(() => _isLoading = true);
    
    try {
      await _firebaseService.refreshCurrentUser();
      setState(() {
        _lastAction = 'Token refreshed successfully';
      });
    } catch (e) {
      setState(() {
        _lastAction = 'Error refreshing token: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAgoraConnection() async {
    setState(() => _isLoading = true);
    
    try {
      // Create test parameters for the connection test
      final testChannelId = 'test-channel-${DateTime.now().millisecondsSinceEpoch}';
      final testToken = 'test-token'; // In a real implementation, this would be a valid token
      final testUid = 123456; // Test numeric UID
      
      final success = await _callService.testAgoraConnection(testChannelId, testToken, testUid);
      setState(() {
        _lastAction = success ? 'Agora connection test passed' : 'Agora connection test failed';
      });
    } catch (e) {
      setState(() {
        _lastAction = 'Agora connection test failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openCallVerification() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AgoraCallVerificationScreen(),
      ),
    );
  }

  Future<void> _clearCallLogs() async {
    setState(() => _isLoading = true);
    
    try {
      await AgoraCallLogger.clearLogs();
      setState(() {
        _lastAction = 'Call logs cleared successfully';
      });
    } catch (e) {
      setState(() {
        _lastAction = 'Error clearing call logs: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testNotification() async {
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.showTestNotification();
      setState(() {
        _lastAction = 'Test notification sent';
      });
    } catch (e) {
      setState(() {
        _lastAction = 'Error sending notification: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFCMToken() async {
    setState(() => _isLoading = true);
    
    try {
      final token = await _notificationService.getFCMToken();
      if (token != null) {
        await Clipboard.setData(ClipboardData(text: token));
        setState(() {
          _lastAction = 'FCM token copied to clipboard: ${token.substring(0, 20)}...';
        });
      } else {
        setState(() {
          _lastAction = 'No FCM token available';
        });
      }
    } catch (e) {
      setState(() {
        _lastAction = 'Error getting FCM token: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearMediaCache() async {
    setState(() => _isLoading = true);
    
    try {
      await MediaCacheService.clearCache();
      setState(() {
        _lastAction = 'Media cache cleared successfully';
      });
    } catch (e) {
      setState(() {
        _lastAction = 'Error clearing cache: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCacheSize() async {
    setState(() => _isLoading = true);
    
    try {
      final size = await MediaCacheService.getCacheSizeFormatted();
      setState(() {
        _lastAction = 'Current cache size: $size';
      });
    } catch (e) {
      setState(() {
        _lastAction = 'Error getting cache size: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportLogs() async {
    setState(() => _isLoading = true);
    
    try {
      final logs = await AgoraCallLogger.getAllLogs();
      await Clipboard.setData(ClipboardData(text: logs.join('\n')));
      setState(() {
        _lastAction = 'Debug logs copied to clipboard (${logs.length} entries)';
      });
    } catch (e) {
      setState(() {
        _lastAction = 'Error exporting logs: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetAllSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text(
          'This will clear all app data including cache, logs, and settings. Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        await MediaCacheService.clearCache();
        await AgoraCallLogger.clearLogs();
        // Add more reset operations as needed
        
        setState(() {
          _lastAction = 'All settings reset successfully';
        });
      } catch (e) {
        setState(() {
          _lastAction = 'Error resetting settings: $e';
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}