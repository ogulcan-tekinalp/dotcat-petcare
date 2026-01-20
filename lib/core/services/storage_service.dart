import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final StorageService instance = StorageService._init();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  StorageService._init();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  bool get isLoggedIn => _userId != null;

  // Fotoğraf yükle
  Future<String?> uploadCatPhoto(File photoFile, String catId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to upload photos');
    }
    
    if (!photoFile.existsSync()) {
      debugPrint('StorageService: Photo file does not exist: ${photoFile.path}');
      return null;
    }
    
    try {
      // Path'i oluştur
      final path = 'users/$_userId/cats/$catId/photo.jpg';
      debugPrint('StorageService: Uploading to path: $path');
      
      final ref = _storage.ref(path);
      
      // Metadata ekle
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=3600',
      );
      
      // Upload task başlat
      final uploadTask = ref.putFile(photoFile, metadata);
      
      // Upload'u bekle
      final snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        // URL'i al
        final downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('StorageService: Upload successful');
        return downloadUrl;
      } else {
        debugPrint('StorageService: Upload failed with state: ${snapshot.state}');
        return null;
      }
    } on FirebaseException catch (e) {
      debugPrint('StorageService: Firebase error: ${e.code} - ${e.message}');
      if (e.code == 'object-not-found') {
        debugPrint('StorageService: Object not found - check Storage rules');
      } else if (e.code == 'unauthorized') {
        debugPrint('StorageService: Unauthorized - check Storage rules');
      } else if (e.code == 'quota-exceeded') {
        debugPrint('StorageService: Quota exceeded');
      }
      return null;
    } catch (e) {
      debugPrint('StorageService: Unexpected error: $e');
      return null;
    }
  }

  // Köpek fotoğraf yükle
  Future<String?> uploadDogPhoto(File photoFile, String dogId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to upload photos');
    }

    if (!photoFile.existsSync()) {
      debugPrint('StorageService: Photo file does not exist: ${photoFile.path}');
      return null;
    }

    try {
      // Path'i oluştur
      final path = 'users/$_userId/dogs/$dogId/photo.jpg';
      debugPrint('StorageService: Uploading to path: $path');

      final ref = _storage.ref(path);

      // Metadata ekle
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=3600',
      );

      // Upload task başlat
      final uploadTask = ref.putFile(photoFile, metadata);

      // Upload'u bekle
      final snapshot = await uploadTask;

      if (snapshot.state == TaskState.success) {
        // URL'i al
        final downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('StorageService: Upload successful');
        return downloadUrl;
      } else {
        debugPrint('StorageService: Upload failed with state: ${snapshot.state}');
        return null;
      }
    } on FirebaseException catch (e) {
      debugPrint('StorageService: Firebase error: ${e.code} - ${e.message}');
      if (e.code == 'object-not-found') {
        debugPrint('StorageService: Object not found - check Storage rules');
      } else if (e.code == 'unauthorized') {
        debugPrint('StorageService: Unauthorized - check Storage rules');
      } else if (e.code == 'quota-exceeded') {
        debugPrint('StorageService: Quota exceeded');
      }
      return null;
    } catch (e) {
      debugPrint('StorageService: Unexpected error: $e');
      return null;
    }
  }

  // Fotoğraf sil
  Future<void> deleteCatPhoto(String catId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to delete photos');
    }

    try {
      final ref = _storage.ref().child('users/$_userId/cats/$catId/photo.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint('StorageService: Delete error: $e');
    }
  }

  // Köpek fotoğraf sil
  Future<void> deleteDogPhoto(String dogId) async {
    if (!isLoggedIn) {
      throw Exception('User must be logged in to delete photos');
    }

    try {
      final ref = _storage.ref().child('users/$_userId/dogs/$dogId/photo.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint('StorageService: Delete error: $e');
    }
  }

  // Fotoğraf URL'inden indir (cache için)
  Future<File?> downloadPhoto(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/photo.jpg');
      await ref.writeToFile(file);
      return file;
    } catch (e) {
      debugPrint('StorageService: Download error: $e');
      return null;
    }
  }
}

