import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjYXTqCAjN4QzVYM6O077Jg0QkJPMjCaI',
    appId: '1:796279147680:web:2d26fe75cb4a9e61a38dc5',
    messagingSenderId: '796279147680',
    projectId: 'proectul-practic',
    authDomain: 'proectul-practic.firebaseapp.com',
    storageBucket: 'proectul-practic.firebasestorage.app',
    measurementId: 'G-EJYC3CWGSJ',
  );
}