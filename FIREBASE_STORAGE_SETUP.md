# Firebase Storage Kurulum Adımları

## ✅ Tamamlanan Adımlar
- [x] Pay as you go plan oluşturuldu
- [x] Storage bucket oluşturuldu

## 🔒 Şimdi Yapılacaklar

### 1. Storage Security Rules'ı Ayarla

Firebase Console'da Storage Security Rules'ı güncelle:

1. **Firebase Console'a git:**
   - https://console.firebase.google.com
   - Projeni seç: `dotcatpetcare`

2. **Storage'a git:**
   - Sol menüden "Storage" seç
   - "Rules" sekmesine tıkla

3. **Rules'ı şu şekilde güncelle:**

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Kullanıcılar sadece kendi klasörlerine erişebilir
    match /users/{userId}/{allPaths=**} {
      // Sadece giriş yapmış kullanıcılar
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

4. **"Publish" butonuna tıkla**

Bu rules:
- ✅ Sadece giriş yapmış kullanıcılara izin verir
- ✅ Her kullanıcı sadece kendi `users/{userId}/` klasörüne erişebilir
- ✅ Başka kullanıcıların verilerine erişim engellenir

### 2. Uygulamayı Test Et

1. **Uygulamayı çalıştır:**
   ```bash
   flutter run
   ```

2. **Test adımları:**
   - Google ile giriş yap
   - Yeni bir kedi ekle
   - Kediye fotoğraf ekle
   - Fotoğrafın yüklendiğini kontrol et
   - Uygulamayı kapat ve tekrar aç
   - Fotoğrafın hala göründüğünü kontrol et (Firebase'den geliyor olmalı)

3. **Hata kontrolü:**
   - Terminal'de hata mesajlarını kontrol et
   - Firebase Console > Storage > Files'da fotoğrafın göründüğünü kontrol et
   - Path: `users/{userId}/cats/{catId}/photo.jpg`

### 3. Sorun Giderme

**Eğer fotoğraf yüklenmiyorsa:**

1. **Storage Rules kontrolü:**
   - Firebase Console > Storage > Rules
   - Rules'ın yukarıdaki gibi olduğundan emin ol
   - "Publish" edildiğinden emin ol

2. **Authentication kontrolü:**
   - Firebase Console > Authentication
   - Kullanıcının listede olduğunu kontrol et

3. **Terminal logları:**
   - `StorageService:` ile başlayan logları kontrol et
   - Hata mesajlarını paylaş

4. **Storage bucket kontrolü:**
   - Firebase Console > Storage > Files
   - Dosyaların göründüğünü kontrol et

### 4. Başarılı Test Sonrası

✅ Fotoğraf yükleme çalışıyorsa:
- Artık kedi fotoğrafları Firebase Storage'da saklanıyor
- Uygulama silinse bile fotoğraflar korunuyor
- Farklı cihazlarda aynı hesap ile giriş yapınca fotoğraflar görünecek

## 📝 Notlar

- **Storage maliyeti:** İlk 5GB ücretsiz, sonrası çok düşük maliyetli
- **Fotoğraf boyutu:** Uygulama JPEG formatında yüklüyor (optimize edilmiş)
- **Path yapısı:** `users/{userId}/cats/{catId}/photo.jpg`
- **Güvenlik:** Her kullanıcı sadece kendi verilerine erişebilir
