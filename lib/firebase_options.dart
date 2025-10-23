
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBBf9A_WM3tvVwPOUZkB0nqjmD1dgJhxX0',
    appId: '1:379672378557:web:e6ff135d2aaac7f6168bd4',
    messagingSenderId: '379672378557',
    projectId: 'carelink-d3788',
    authDomain: 'carelink-d3788.firebaseapp.com',
    storageBucket: 'carelink-d3788.firebasestorage.app',
    measurementId: 'G-WECVN94B42',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAra8dyyTDYpQi4JAaeaSp6KDn2YGv2sa8',
    appId: '1:379672378557:android:9a70f4f520be8cc9168bd4',
    messagingSenderId: '379672378557',
    projectId: 'carelink-d3788',
    storageBucket: 'carelink-d3788.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBC6bWg53nvhd76M1-ofFS1NP7mBEvw6Co',
    appId: '1:379672378557:ios:48d4db99c767b8c1168bd4',
    messagingSenderId: '379672378557',
    projectId: 'carelink-d3788',
    storageBucket: 'carelink-d3788.firebasestorage.app',
    iosBundleId: 'com.example.carelink',
  );
}
