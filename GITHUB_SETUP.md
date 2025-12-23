# GitHub'a Yükleme Öncesi Kontrol Listesi

## ✅ Yapılan Düzeltmeler

1. **.gitignore Güncellendi**
   - `GoogleService-Info.plist` eklendi (API key'ler git'e gitmeyecek)
   - `google-services.json` eklendi
   - Firebase config dosyaları ignore edildi

2. **Android Application ID Düzeltildi**
   - `com.example.dotcat` → `com.dotcat.petcare`
   - Namespace güncellendi

3. **Debug Print Statements**
   - Tüm `print()` statements `debugPrint()` ile değiştirildi
   - Production'da console'a yazılmayacak

4. **Timezone Düzeltildi**
   - Hard-coded `Europe/Istanbul` yerine kullanıcının sistem timezone'u kullanılıyor

5. **Storage Rules Dosyası Oluşturuldu**
   - `storage.rules` dosyası eklendi
   - Firebase Console'a yüklenmeli

## 📋 GitHub'a Yüklemeden Önce Yapılması Gerekenler

### 1. Firebase Config Dosyalarını Kontrol Et
```bash
# Bu dosyalar .gitignore'da olmalı, git'e commit edilmemeli
ls -la ios/GoogleService-Info.plist
ls -la android/app/google-services.json
```

### 2. Git Status Kontrolü
```bash
git status
# GoogleService-Info.plist ve google-services.json görünmemeli
```

### 3. Firebase Storage Rules'ı Yükle
Firebase Console → Storage → Rules sekmesine git ve `storage.rules` dosyasındaki kuralları yapıştır.

### 4. Firestore Rules'ı Kontrol Et
Firebase Console → Firestore Database → Rules sekmesinde `firestore.rules` dosyasındaki kuralların yüklü olduğundan emin ol.

## 🚀 GitHub'a Yükleme Komutları

```bash
# 1. Git repository başlat (eğer yoksa)
git init

# 2. Tüm dosyaları ekle
git add .

# 3. İlk commit
git commit -m "Initial commit: Dotcat PetCare App"

# 4. GitHub'da repository oluştur, sonra:
git remote add origin https://github.com/KULLANICI_ADI/dotcat.git
git branch -M main
git push -u origin main
```

## ⚠️ ÖNEMLİ UYARILAR

1. **API Keys**: `GoogleService-Info.plist` ve `google-services.json` dosyaları asla git'e commit edilmemeli. `.gitignore`'da olduklarından emin ol.

2. **Production Signing**: Android için production keystore oluşturulmalı ve `build.gradle.kts`'de kullanılmalı.

3. **Firebase Rules**: Storage ve Firestore rules'ları Firebase Console'da yayınlanmalı.

4. **Environment Variables**: Gelecekte API key'ler için environment variables kullanılabilir.

## 📝 README.md Önerisi

GitHub repository'sine şu bilgileri içeren bir README.md ekle:
- Proje açıklaması
- Kurulum talimatları
- Firebase setup adımları
- Build komutları
- Katkıda bulunma rehberi

