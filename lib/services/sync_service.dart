import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool get isSandboxMode => AuthService().isSandboxMode;

  /// Loads the user state from either Cloud Firestore or local JSON file (sandbox).
  Future<Map<String, dynamic>?> loadUserData(String uid) async {
    if (!isSandboxMode) {
      try {
        final doc = await fs.FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          return doc.data();
        }
        return null;
      } catch (e) {
        // Fallback to local cache if offline
        try {
          final doc = await fs.FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get(const fs.GetOptions(source: fs.Source.cache));
          if (doc.exists) {
            return doc.data();
          }
        } catch (_) {}
        rethrow;
      }
    } else {
      // Sandbox mode: read from local file
      try {
        final file = await _getSandboxFile(uid);
        if (await file.exists()) {
          final contents = await file.readAsString();
          return jsonDecode(contents) as Map<String, dynamic>;
        }
      } catch (e) {
        // Log error and return null
        debugPrint('Error loading sandbox data: $e');
      }
      return null;
    }
  }

  /// Saves the user state to either Cloud Firestore or local JSON file (sandbox).
  Future<void> saveUserData(String uid, Map<String, dynamic> data) async {
    // Add last sync time to data
    final now = DateTime.now();
    data['lastSyncTime'] = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (!isSandboxMode) {
      await fs.FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, fs.SetOptions(merge: true));
    } else {
      // Sandbox mode: write to local file
      try {
        final file = await _getSandboxFile(uid);
        await file.writeAsString(jsonEncode(data));
      } catch (e) {
        debugPrint('Error saving sandbox data: $e');
      }
    }
  }

  /// Clears local sandbox cache if necessary.
  Future<void> clearLocalUserData(String uid) async {
    if (isSandboxMode) {
      try {
        final file = await _getSandboxFile(uid);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error clearing sandbox data: $e');
      }
    }
  }

  Future<File> _getSandboxFile(String uid) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/alina_sandbox_user_$uid.json');
  }
}
