// App Constants and Configuration
class AppConstants {
  // App Information
  static const String appName = 'Abdi Wave Chat';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Firebase Configuration
  static const String firebaseProjectId = 'abdiwavee';
  static const String firebaseApiKey = 'AIzaSyB5Ufc0N4WMuapF6z_tBesYDXQVZADs0RE';
  static const String firebaseAuthDomain = 'abdiwavee.firebaseapp.com';
  static const String firebaseStorageBucket = 'abdiwavee.firebasestorage.app';
  static const String firebaseMessagingSenderId = '315443508332';
  static const String firebaseAppId = '1:315443508332:web:a3a3b5e0cb1bf6aea69449';

  // Agora Configuration
  static const String agoraAppId = 'b7487b8a48da4f89a4285c92e454a96f';
  static const String agoraAppCertificate = '3305146df1a942e5ae0c164506e16007';
  static const String agoraTokenServerUrl = 'https://jgfjkwtzkzctpwyqvtri.supabase.co/functions/v1/generateAgoraToken';
  
  // Cloudinary Configuration
  static const String cloudinaryCloudName = 'your-cloudinary-cloud-name';
  static const String cloudinaryApiKey = 'your-cloudinary-api-key';
  static const String cloudinaryApiSecret = 'your-cloudinary-api-secret';
  static const String cloudinaryUploadPreset = 'chat_media_preset';

  // Chat Configuration
  static const int maxMessageLength = 1000;
  static const int maxFileSize = 50 * 1024 * 1024; // 50MB
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB
  static const int typingIndicatorTimeout = 3; // seconds
  static const int messageLoadLimit = 50;
  static const int chatListLoadLimit = 20;

  // Call Configuration
  static const int maxCallDuration = 3600; // 1 hour in seconds
  static const int callTimeoutDuration = 30; // seconds
  static const int reconnectAttempts = 3;
  static const int reconnectDelay = 2; // seconds

  // UI Configuration
  static const double borderRadius = 12.0;
  static const double messageBubbleRadius = 16.0;
  static const double buttonRadius = 8.0;
  static const double cardElevation = 2.0;
  static const double listItemHeight = 72.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration typingAnimationDuration = Duration(milliseconds: 1500);

  // Cache Configuration
  static const int imageCacheMaxAge = 7; // days
  static const int videoCacheMaxAge = 3; // days
  static const int audioCacheMaxAge = 5; // days
  static const int maxCacheSize = 500 * 1024 * 1024; // 500MB

  // Network Configuration
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration connectivityCheckInterval = Duration(seconds: 5);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Database Configuration
  static const String localDatabaseName = 'abdi_wave_local.db';
  static const int localDatabaseVersion = 1;
  static const String messagesTable = 'messages';
  static const String chatsTable = 'chats';
  static const String usersTable = 'users';
  static const String callsTable = 'calls';

  // Security Configuration
  static const int tokenExpiryTime = 24 * 3600; // 24 hours
  static const int sessionTimeout = 7 * 24 * 3600; // 7 days
  static const int maxLoginAttempts = 5;
  static const Duration loginCooldown = Duration(minutes: 15);

  // Feature Flags
  static const bool enableOfflineMode = true;
  static const bool enableVideoCompress = true;
  static const bool enableImageCompress = true;
  static const bool enablePushNotifications = true;
  static const bool enableTypingIndicators = true;
  static const bool enableReadReceipts = true;
  static const bool enableLocationSharing = true;
  static const bool enableVoiceMessages = true;
  static const bool enableScreenSharing = true;
  static const bool enableGroupCalls = false; // Future feature

  // Notification Configuration
  static const String defaultNotificationChannelId = 'abdi_wave_messages';
  static const String defaultNotificationChannelName = 'Messages';
  static const String callNotificationChannelId = 'abdi_wave_calls';
  static const String callNotificationChannelName = 'Calls';

  // Error Messages
  static const String networkErrorMessage = 'Network connection failed. Please check your internet connection.';
  static const String authErrorMessage = 'Authentication failed. Please try logging in again.';
  static const String serverErrorMessage = 'Server error occurred. Please try again later.';
  static const String cameraPermissionMessage = 'Camera permission is required for video calls.';
  static const String microphonePermissionMessage = 'Microphone permission is required for calls.';
  static const String storagePermissionMessage = 'Storage permission is required to save media files.';

  // Success Messages
  static const String messageSentSuccess = 'Message sent successfully';
  static const String callConnectedSuccess = 'Call connected successfully';
  static const String mediaUploadSuccess = 'Media uploaded successfully';
  static const String profileUpdateSuccess = 'Profile updated successfully';

  // File Extensions
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  static const List<String> supportedVideoFormats = ['mp4', 'avi', 'mov', 'mkv', 'webm'];
  static const List<String> supportedAudioFormats = ['mp3', 'wav', 'aac', 'm4a', 'ogg'];
  static const List<String> supportedDocumentFormats = ['pdf', 'doc', 'docx', 'txt', 'rtf'];

  // URL Patterns
  static const String urlPattern = r'https?://(?:[-\w.])+(?::\d+)?(?:/(?:[\w/_.])*(?:\?(?:[\w&=%.])*)?(?:#(?:\w*))?)?';
  static const String emailPattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phonePattern = r'^\+?[1-9]\d{1,14}$';

  // Environment Configuration
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  static const bool enableLogging = !isProduction;
  static const bool enableDebugMode = !isProduction;
  static const bool enableAnalytics = isProduction;

  // Performance Optimization
  static const int imageCompressionQuality = 85;
  static const int videoCompressionQuality = 75;
  static const int thumbnailSize = 300;
  static const int previewImageSize = 800;
  static const int maxConcurrentUploads = 3;
  static const int maxConcurrentDownloads = 5;

  // API Endpoints
  static const String baseApiUrl = 'https://api.abdiwave.com/v1';
  static const String tokenEndpoint = '/auth/token';
  static const String uploadEndpoint = '/media/upload';
  static const String downloadEndpoint = '/media/download';
  static const String callEndpoint = '/call/initiate';

  // Social Media Integration
  static const String googleSignInClientId = 'your-google-client-id';
  static const String facebookAppId = 'your-facebook-app-id';
  static const String twitterApiKey = 'your-twitter-api-key';

  // Development Configuration
  static const String debugTag = 'ABDI_WAVE_DEBUG';
  static const bool enableNetworkLogs = enableDebugMode;
  static const bool enablePerformanceLogs = enableDebugMode;
  static const bool enableCrashlytics = isProduction;

  // Regional Configuration
  static const String defaultLanguage = 'en';
  static const String defaultCountry = 'US';
  static const String defaultTimezone = 'UTC';
  static const List<String> supportedLanguages = ['en', 'bn', 'ar', 'hi', 'es', 'fr'];

  // Business Logic Constants
  static const int minPasswordLength = 8;
  static const int maxUsernameLength = 30;
  static const int minUsernameLength = 3;
  static const int maxDisplayNameLength = 50;
  static const int maxBioLength = 150;
  static const int maxGroupMembers = 256;
  static const int maxChannelMembers = 1000;
}

// API Response Status Codes
class ApiStatusCodes {
  static const int success = 200;
  static const int created = 201;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int serverError = 500;
  static const int serviceUnavailable = 503;
}

// Local Storage Keys
class StorageKeys {
  static const String userToken = 'user_token';
  static const String userId = 'user_id';
  static const String userProfile = 'user_profile';
  static const String chatSettings = 'chat_settings';
  static const String notificationSettings = 'notification_settings';
  static const String themeMode = 'theme_mode';
  static const String language = 'language';
  static const String isFirstTime = 'is_first_time';
  static const String lastSyncTime = 'last_sync_time';
  static const String offlineMessages = 'offline_messages';
}

// Event Names for Analytics
class AnalyticsEvents {
  static const String appOpened = 'app_opened';
  static const String userSignIn = 'user_sign_in';
  static const String userSignOut = 'user_sign_out';
  static const String messageSent = 'message_sent';
  static const String messageReceived = 'message_received';
  static const String callInitiated = 'call_initiated';
  static const String callReceived = 'call_received';
  static const String callEnded = 'call_ended';
  static const String mediaShared = 'media_shared';
  static const String profileUpdated = 'profile_updated';
  static const String settingsChanged = 'settings_changed';
}

// Firestore Collection Names
class FirestoreCollections {
  static const String users = 'users';
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String calls = 'calls';
  static const String notifications = 'notifications';
  static const String settings = 'settings';
  static const String reports = 'reports';
  static const String analytics = 'analytics';
}

// Firebase Storage Paths
class StoragePaths {
  static const String profileImages = 'profile_images';
  static const String chatImages = 'chat_images';
  static const String chatVideos = 'chat_videos';
  static const String chatAudios = 'chat_audios';
  static const String chatDocuments = 'chat_documents';
  static const String thumbnails = 'thumbnails';
  static const String temp = 'temp';
}