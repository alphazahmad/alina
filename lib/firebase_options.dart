import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  /// Returns `null` if the options are not yet configured (contain placeholders),
  /// signaling the app to run in "Local Sandbox Mode" with offline capabilities.
  static FirebaseOptions? get currentPlatform {
    if (apiKey.isEmpty || apiKey == 'PLACEHOLDER' || apiKey.startsWith('YOUR_')) {
      return null;
    }
    return android;
  }

  // To enable Cloud Sync, configure your Firebase project and paste your keys here:
  static const String apiKey = 'PLACEHOLDER';
  static const String appId = 'PLACEHOLDER';
  static const String messagingSenderId = 'PLACEHOLDER';
  static const String projectId = 'PLACEHOLDER';
  static const String storageBucket = 'PLACEHOLDER';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );
}
