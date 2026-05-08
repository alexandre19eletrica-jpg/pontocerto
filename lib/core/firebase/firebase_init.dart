import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:pontocerto/firebase_options.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Persistência local no Windows já deu bloqueios/long stalls em alguns setups.
  final persistenceOk =
      kIsWeb || defaultTargetPlatform != TargetPlatform.windows;
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: persistenceOk,
  );
}
