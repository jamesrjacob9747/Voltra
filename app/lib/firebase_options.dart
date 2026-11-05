import 'package:firebase_core/firebase_core.dart';

/// The Firebase project's Android app identifiers, copied from its google-services.json.
/// Google documents these as identifiers, not secrets: sending pushes needs the server's
/// service-account key, which never ships in the app. Set this to null to turn push notifications off.
// ignore: unnecessary_nullable_for_final_variable_declarations
const FirebaseOptions? voltraFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAOG9PiMBSdcg0JOQKx1gDTZnPX-nUjp6c',
  appId: '1:135612073738:android:28a5f4eeb9415794c79cf3',
  messagingSenderId: '135612073738',
  projectId: 'voltra-8199',
  storageBucket: 'voltra-8199.firebasestorage.app',
);
