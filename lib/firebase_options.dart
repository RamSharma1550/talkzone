import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS not configured.');
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCRFiFAjdC-W7h7bAM_aUTONLH8TMN9u7g',
    authDomain: 'talkzone-b574d.firebaseapp.com',
    projectId: 'talkzone-b574d',
    storageBucket: 'talkzone-b574d.firebasestorage.app',
    messagingSenderId: '145717484019',
    appId: '1:145717484019:web:2ba1fac7377d6bf37e5a86',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCRFiFAjdC-W7h7bAM_aUTONLH8TMN9u7g',
    authDomain: 'talkzone-b574d.firebaseapp.com',
    projectId: 'talkzone-b574d',
    storageBucket: 'talkzone-b574d.firebasestorage.app',
    messagingSenderId: '145717484019',
    appId: '1:145717484019:web:2ba1fac7377d6bf37e5a86',
  );
}
