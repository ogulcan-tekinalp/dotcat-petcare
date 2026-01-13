/// DotCat uygulaması için custom exception sınıfları
///
/// Bu sınıflar, uygulamada oluşan hataları daha iyi yönetmemizi
/// ve kullanıcıya anlamlı mesajlar göstermemizi sağlar.
library;

/// Base exception class
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Generic app exception (concrete implementation)
class GenericAppException extends AppException {
  GenericAppException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

// ============ NETWORK & CONNECTIVITY EXCEPTIONS ============

/// Internet bağlantısı yok
class NoInternetException extends AppException {
  NoInternetException([String? message])
      : super(
          message ?? 'İnternet bağlantısı yok. Lütfen bağlantınızı kontrol edin.',
          code: 'NO_INTERNET',
        );
}

/// Server'a ulaşılamıyor
class ServerUnreachableException extends AppException {
  ServerUnreachableException([String? message])
      : super(
          message ?? 'Sunucuya ulaşılamıyor. Lütfen daha sonra tekrar deneyin.',
          code: 'SERVER_UNREACHABLE',
        );
}

/// Request timeout
class TimeoutException extends AppException {
  TimeoutException([String? message])
      : super(
          message ?? 'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.',
          code: 'TIMEOUT',
        );
}

// ============ AUTHENTICATION EXCEPTIONS ============

/// Kimlik doğrulama hatası
class AuthException extends AppException {
  AuthException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Kullanıcı giriş yapmamış
class NotAuthenticatedException extends AuthException {
  NotAuthenticatedException([String? message])
      : super(
          message ?? 'Bu işlem için giriş yapmanız gerekiyor.',
          code: 'NOT_AUTHENTICATED',
        );
}

/// Geçersiz kimlik bilgileri
class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException([String? message])
      : super(
          message ?? 'E-posta veya şifre hatalı.',
          code: 'INVALID_CREDENTIALS',
        );
}

/// Email zaten kullanımda
class EmailAlreadyInUseException extends AuthException {
  EmailAlreadyInUseException([String? message])
      : super(
          message ?? 'Bu e-posta adresi zaten kullanılıyor.',
          code: 'EMAIL_IN_USE',
        );
}

/// Weak password
class WeakPasswordException extends AuthException {
  WeakPasswordException([String? message])
      : super(
          message ?? 'Şifre çok zayıf. Lütfen daha güçlü bir şifre seçin.',
          code: 'WEAK_PASSWORD',
        );
}

/// Token süresi dolmuş
class TokenExpiredException extends AuthException {
  TokenExpiredException([String? message])
      : super(
          message ?? 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.',
          code: 'TOKEN_EXPIRED',
        );
}

// ============ FIRESTORE/DATABASE EXCEPTIONS ============

/// Firestore işlem hatası
class FirestoreException extends AppException {
  FirestoreException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Document bulunamadı
class DocumentNotFoundException extends FirestoreException {
  final String documentId;

  DocumentNotFoundException(this.documentId, [String? message])
      : super(
          message ?? 'Belge bulunamadı: $documentId',
          code: 'DOCUMENT_NOT_FOUND',
        );
}

/// Permission denied
class PermissionDeniedException extends FirestoreException {
  PermissionDeniedException([String? message])
      : super(
          message ?? 'Bu işlem için yetkiniz yok.',
          code: 'PERMISSION_DENIED',
        );
}

/// SQLite veritabanı hatası
class DatabaseException extends AppException {
  DatabaseException(super.message, {super.code, super.originalError, super.stackTrace});
}

// ============ STORAGE EXCEPTIONS ============

/// Storage işlem hatası
class StorageException extends AppException {
  StorageException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Dosya yüklenemedi
class FileUploadException extends StorageException {
  FileUploadException([String? message])
      : super(
          message ?? 'Dosya yüklenemedi. Lütfen tekrar deneyin.',
          code: 'FILE_UPLOAD_FAILED',
        );
}

/// Dosya çok büyük
class FileTooLargeException extends StorageException {
  final int maxSizeInMB;

  FileTooLargeException(this.maxSizeInMB, [String? message])
      : super(
          message ?? 'Dosya çok büyük. Maksimum boyut: ${maxSizeInMB}MB',
          code: 'FILE_TOO_LARGE',
        );
}

// ============ VALIDATION EXCEPTIONS ============

/// Validasyon hatası
class ValidationException extends AppException {
  final String field;

  ValidationException(this.field, super.message, {super.code});

  @override
  String toString() => 'ValidationException($field): $message';
}

/// Gerekli alan boş
class RequiredFieldException extends ValidationException {
  RequiredFieldException(String field, [String? message])
      : super(
          field,
          message ?? '$field alanı zorunludur.',
          code: 'REQUIRED_FIELD',
        );
}

/// Geçersiz format
class InvalidFormatException extends ValidationException {
  InvalidFormatException(String field, [String? message])
      : super(
          field,
          message ?? '$field geçersiz formatta.',
          code: 'INVALID_FORMAT',
        );
}

// ============ SYNC EXCEPTIONS ============

/// Senkronizasyon hatası
class SyncException extends AppException {
  SyncException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Conflict hatası (offline-first için)
class DataConflictException extends SyncException {
  final String entityType;
  final String entityId;

  DataConflictException(this.entityType, this.entityId, [String? message])
      : super(
          message ?? '$entityType verisi çakıştı (ID: $entityId). Manuel çözüm gerekiyor.',
          code: 'DATA_CONFLICT',
        );
}

// ============ NOTIFICATION EXCEPTIONS ============

/// Bildirim hatası
class NotificationException extends AppException {
  NotificationException(super.message, {super.code, super.originalError, super.stackTrace});
}

/// Notification permission denied
class NotificationPermissionDeniedException extends NotificationException {
  NotificationPermissionDeniedException([String? message])
      : super(
          message ?? 'Bildirim izni verilmedi. Lütfen ayarlardan bildirimleri açın.',
          code: 'NOTIFICATION_PERMISSION_DENIED',
        );
}

// ============ EXCEPTION FACTORY ============

/// Firebase ve diğer platform hatalarını custom exception'lara çevir
class ExceptionFactory {
  /// Firebase Auth hatalarını çevir
  static AppException fromFirebaseAuthException(dynamic error) {
    final errorCode = _getErrorCode(error);

    switch (errorCode) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return InvalidCredentialsException();
      case 'email-already-in-use':
        return EmailAlreadyInUseException();
      case 'weak-password':
        return WeakPasswordException();
      case 'too-many-requests':
        return AuthException(
          'Çok fazla başarısız deneme. Lütfen daha sonra tekrar deneyin.',
          code: 'TOO_MANY_REQUESTS',
        );
      case 'network-request-failed':
        return NoInternetException();
      default:
        return AuthException(
          'Giriş yapılamadı: ${_getErrorMessage(error)}',
          code: errorCode,
          originalError: error,
        );
    }
  }

  /// Firestore hatalarını çevir
  static AppException fromFirestoreException(dynamic error) {
    final errorCode = _getErrorCode(error);

    switch (errorCode) {
      case 'permission-denied':
        return PermissionDeniedException();
      case 'not-found':
        return DocumentNotFoundException('Unknown');
      case 'unavailable':
        return ServerUnreachableException('Firestore sunucusuna ulaşılamıyor.');
      case 'deadline-exceeded':
        return TimeoutException('Firestore işlemi zaman aşımına uğradı.');
      default:
        return FirestoreException(
          'Veritabanı hatası: ${_getErrorMessage(error)}',
          code: errorCode,
          originalError: error,
        );
    }
  }

  /// Storage hatalarını çevir
  static AppException fromStorageException(dynamic error) {
    final errorCode = _getErrorCode(error);

    switch (errorCode) {
      case 'unauthorized':
        return PermissionDeniedException('Storage yetkiniz yok.');
      case 'canceled':
        return StorageException('Yükleme iptal edildi.', code: 'UPLOAD_CANCELED');
      case 'unknown':
        return FileUploadException();
      default:
        return StorageException(
          'Dosya işlemi hatası: ${_getErrorMessage(error)}',
          code: errorCode,
          originalError: error,
        );
    }
  }

  /// Generic error'ları çevir
  static AppException fromError(dynamic error, {String? defaultMessage}) {
    if (error is AppException) return error;

    // Platform exception kontrolü
    if (error.toString().contains('firebase_auth')) {
      return fromFirebaseAuthException(error);
    } else if (error.toString().contains('cloud_firestore')) {
      return fromFirestoreException(error);
    } else if (error.toString().contains('firebase_storage')) {
      return fromStorageException(error);
    }

    // Generic exception
    return GenericAppException(
      defaultMessage ?? 'Bir hata oluştu: ${error.toString()}',
      code: 'UNKNOWN',
      originalError: error,
    );
  }

  // Helper methods
  static String _getErrorCode(dynamic error) {
    try {
      return error.code?.toString() ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  static String _getErrorMessage(dynamic error) {
    try {
      return error.message?.toString() ?? error.toString();
    } catch (_) {
      return error.toString();
    }
  }
}
