# Apple Store Reddetme Sorunlarının Çözümü

Bu dosya, Apple Store'un reddettiği 3 sorunu çözmek için yapılan değişiklikleri açıklar.

## ✅ Tamamlanan Değişiklikler

### 1. Sign in with Apple Eklendi
- ✅ `sign_in_with_apple` paketi `pubspec.yaml`'a eklendi
- ✅ `AuthService`'e `signInWithApple()` metodu eklendi
- ✅ Login ekranına Sign in with Apple butonu eklendi (Google'dan önce)
- ✅ iOS entitlements dosyası oluşturuldu (`ios/Runner/Runner.entitlements`)

### 2. Account Deletion Eklendi
- ✅ `AuthService`'e `deleteAccount()` metodu eklendi
- ✅ Firestore verilerini silme fonksiyonu eklendi
- ✅ Storage dosyalarını silme fonksiyonu eklendi
- ✅ Settings ekranına "Delete Account" butonu eklendi
- ✅ Onay dialogu ve uyarı mesajları eklendi
- ✅ Lokalizasyon anahtarları eklendi

### 3. Lokalizasyon
- ✅ Account deletion için tüm dillerde çeviriler eklendi

## 🔧 Yapılması Gereken Manuel Adımlar

### 1. Sign in with Apple Yapılandırması

**ÖNEMLİ:** Xcode üzerinden yapılandırma yapmak daha kolaydır ve otomatik olarak Apple Developer Portal'ı da günceller.

#### Yöntem 1: Xcode Üzerinden (Önerilen - Daha Kolay)

1. **Xcode'da Projeyi Açın:**
   ```bash
   cd ios
   open Runner.xcworkspace
   ```
   Veya Finder'dan `ios/Runner.xcworkspace` dosyasını çift tıklayarak açın.

2. **Target'ı Seçin:**
   - Sol taraftaki proje navigator'da "Runner" projesini seçin
   - Ortadaki target listesinden "Runner" target'ını seçin

3. **Signing & Capabilities Sekmesine Gidin:**
   - Üst kısımdaki "Signing & Capabilities" sekmesine tıklayın

4. **Sign In with Apple Capability'sini Ekleyin:**
   - Sol üstteki "+ Capability" butonuna tıklayın
   - Açılan listeden "Sign In with Apple" seçeneğini bulun ve tıklayın
   - Xcode otomatik olarak:
     - Entitlements dosyasını güncelleyecek
     - Apple Developer Portal'ı güncelleyecek (eğer giriş yaptıysanız)

5. **Team ve Bundle ID Kontrolü:**
   - "Team" alanında doğru Apple Developer hesabınızın seçili olduğundan emin olun
   - "Bundle Identifier" alanında `com.dotcat.petcare` olduğunu kontrol edin

#### Yöntem 2: Apple Developer Portal Üzerinden (Manuel)

Eğer Xcode'da otomatik yapılandırma çalışmazsa:

1. **Apple Developer Portal'a Giriş:**
   - [developer.apple.com](https://developer.apple.com/) adresine gidin
   - Apple ID'nizle giriş yapın

2. **Identifiers Bölümüne Erişim:**
   - Ana sayfada sol menüden **"Certificates, Identifiers & Profiles"** seçeneğini bulun
   - Eğer göremiyorsanız, doğrudan şu linke gidin: https://developer.apple.com/account/resources/identifiers/list
   - Veya üst menüden **"Account"** > **"Certificates, Identifiers & Profiles"** yolunu takip edin

3. **App ID'yi Bulun:**
   - Sol menüden **"Identifiers"** seçeneğine tıklayın
   - Listeden `com.dotcat.petcare` App ID'sini bulun ve tıklayın
   - Eğer yoksa, "+" butonuna tıklayarak yeni bir App ID oluşturun

4. **Sign In with Apple'ı Aktif Edin:**
   - App ID detay sayfasında **"Sign In with Apple"** seçeneğini bulun
   - Checkbox'ı işaretleyin
   - Sağ üstteki **"Save"** butonuna tıklayın

#### Entitlements Dosyası Kontrolü

Xcode'da capability ekledikten sonra, `ios/Runner/Runner.entitlements` dosyasında şu satırların olduğunu kontrol edin:
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

Eğer yoksa, dosyayı manuel olarak düzenleyebilir veya Xcode'da tekrar capability eklemeyi deneyebilirsiniz.

#### Firebase Console Yapılandırması:

1. **Firebase Console'a Giriş:**
   - [Firebase Console](https://console.firebase.google.com/) adresine gidin
   - Projenizi seçin (`dotcatpetcare`)

2. **Apple Provider'ını Etkinleştirin:**
   - Sol menüden **"Authentication"** seçeneğine tıklayın
   - Üst menüden **"Sign-in method"** sekmesine gidin
   - Provider listesinden **"Apple"** seçeneğini bulun ve tıklayın
   - **"Enable"** toggle'ını açın
   - **"Save"** butonuna tıklayın

**Not:** Firebase, Apple Sign In için ek bir yapılandırma gerektirmez. Xcode ve Apple Developer Portal yapılandırması yeterlidir.

### 2. Support URL Güncellemesi

App Store Connect'te:
1. App Store Connect'e giriş yapın
2. Uygulamanızı seçin
3. "App Information" bölümüne gidin
4. "Support URL" alanını güncelleyin:
   - GitHub repository yerine gerçek bir destek sayfası URL'si kullanın
   - Örnek: `https://dotcat.com/support` veya `https://yourdomain.com/support`
   - Bu sayfada kullanıcıların soru sorabileceği ve destek alabileceği bilgiler olmalı

**Not:** Eğer henüz bir destek sayfanız yoksa, hızlıca bir sayfa oluşturabilirsiniz:
- GitHub Pages kullanarak basit bir HTML sayfası
- Veya herhangi bir web hosting servisi

### 3. Paketleri Yükleme

Terminal'de şu komutu çalıştırın:
```bash
flutter pub get
```

### 4. Test Etme

1. **Sign in with Apple Testi:**
   - Uygulamayı iOS cihazda çalıştırın
   - Login ekranında "Sign in with Apple" butonunu görün
   - Butona tıklayıp Apple ID ile giriş yapmayı test edin

2. **Account Deletion Testi:**
   - Settings > Account bölümüne gidin
   - "Delete Account" butonuna tıklayın
   - Onay dialogunu kontrol edin
   - Hesap silme işlemini test edin (test hesabı ile!)

## 📝 Önemli Notlar

1. **Sign in with Apple** sadece iOS 13+ cihazlarda çalışır
2. **Account Deletion** işlemi geri alınamaz - test ederken dikkatli olun
3. **Support URL** mutlaka çalışan bir web sayfası olmalı, GitHub repository linki kabul edilmez
4. Uygulamayı App Store'a tekrar göndermeden önce tüm değişiklikleri test edin

## 🚀 Sonraki Adımlar

1. Yukarıdaki manuel adımları tamamlayın
2. Uygulamayı test edin
3. Yeni build oluşturun (`flutter build ios`)
4. App Store Connect'e yeni versiyonu yükleyin
5. Review Notes'da şu bilgileri ekleyin:
   - "Sign in with Apple has been added as an alternative login option"
   - "Account deletion feature has been added in Settings > Account"
   - "Support URL has been updated to a functional support page"

## 📞 Sorun Giderme

### Apple Developer Portal'da "Identifiers" bölümünü bulamıyorum:

**Çözüm 1: Doğrudan Link Kullanın**
- Şu linke gidin: https://developer.apple.com/account/resources/identifiers/list
- Veya: https://developer.apple.com/account/resources/identifiers

**Çözüm 2: Xcode Üzerinden Yapın (Önerilen)**
- Xcode'da capability eklediğinizde otomatik olarak Apple Developer Portal güncellenir
- Xcode'da "Signing & Capabilities" sekmesinde "+ Capability" > "Sign In with Apple" ekleyin
- Xcode otomatik olarak gerekli yapılandırmayı yapar

**Çözüm 3: Farklı Tarayıcı Deneyin**
- Safari, Chrome veya Firefox gibi farklı bir tarayıcı kullanın
- JavaScript'in aktif olduğundan emin olun

**Çözüm 4: Menü Yolu**
1. developer.apple.com ana sayfasına gidin
2. Üst menüden **"Account"** seçeneğine tıklayın
3. Sol menüden **"Certificates, Identifiers & Profiles"** seçeneğini bulun
4. Açılan sayfada sol menüden **"Identifiers"** seçeneğine tıklayın

### Sign in with Apple çalışmıyor:
- Entitlements dosyasının Xcode'da doğru yapılandırıldığından emin olun
- `ios/Runner/Runner.entitlements` dosyasında `com.apple.developer.applesignin` key'inin olduğunu kontrol edin
- Xcode'da "Signing & Capabilities" sekmesinde "Sign In with Apple" capability'sinin eklendiğini kontrol edin
- Firebase Console'da Apple provider'ının etkin olduğunu kontrol edin
- iOS 13+ cihazda test ettiğinizden emin olun (Sign in with Apple iOS 13+ gerektirir)

### Account deletion hata veriyor:
- Firebase Security Rules'ın silme işlemlerine izin verdiğinden emin olun
- Firestore ve Storage'da kullanıcı verilerinin doğru yapılandırıldığını kontrol edin

