# GitHub'a Push Etme Rehberi

## 📋 Adım Adım Talimatlar

### 1. Git Repository Başlat (Eğer Henüz Başlatılmadıysa)

```bash
cd /Users/ogulcan/dotcat
git init
```

### 2. Tüm Dosyaları Ekle

```bash
git add .
```

### 3. Firebase Config Dosyalarının Ignore Edildiğini Kontrol Et

```bash
git status
```

**Görmemen gerekenler:**
- ❌ `ios/GoogleService-Info.plist`
- ❌ `ios/Runner/GoogleService-Info.plist`
- ❌ `android/app/google-services.json`

Eğer görünüyorsa:
```bash
# Dosyaları git'ten kaldır (dosyalar silinmez, sadece git tracking'den çıkar)
git rm --cached ios/GoogleService-Info.plist
git rm --cached ios/Runner/GoogleService-Info.plist
git rm --cached android/app/google-services.json 2>/dev/null || true

# .gitignore'ı kontrol et
cat .gitignore | grep -i google
```

### 4. İlk Commit Yap

```bash
git commit -m "Initial commit: Dotcat PetCare App v1.0.0

- Flutter cat care assistant application
- Firebase integration (Auth, Firestore, Storage)
- Multi-language support (TR, EN, DE, ES, AR)
- Reminder system with local notifications
- Weight tracking with charts
- Calendar view for events"
```

### 5. GitHub'da Repository Oluştur

1. https://github.com/new adresine git
2. Repository adı: `dotcat` (veya istediğin isim)
3. **Public** veya **Private** seç (öneri: Private - API key'ler var)
4. **"Initialize this repository with a README"** seçme (zaten README.md var)
5. **"Add .gitignore"** seçme (zaten var)
6. **"Choose a license"** opsiyonel
7. **"Create repository"** butonuna tıkla

### 6. Remote Repository'yi Ekle

GitHub'da repository oluşturduktan sonra, GitHub sana bir URL verecek. Şu formatta olacak:
- HTTPS: `https://github.com/KULLANICI_ADI/dotcat.git`
- SSH: `git@github.com:KULLANICI_ADI/dotcat.git`

```bash
# KULLANICI_ADI'ni kendi GitHub kullanıcı adınla değiştir
git remote add origin https://github.com/KULLANICI_ADI/dotcat.git

# Veya SSH kullanıyorsan:
# git remote add origin git@github.com:KULLANICI_ADI/dotcat.git
```

### 7. Branch'i Main Olarak Ayarla

```bash
git branch -M main
```

### 8. Push Et

```bash
git push -u origin main
```

Eğer ilk kez push ediyorsan, GitHub kullanıcı adı ve şifre (veya Personal Access Token) isteyebilir.

**Not:** GitHub artık şifre kabul etmiyor. Personal Access Token kullanman gerekiyor:
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. "Generate new token" → "repo" yetkisini seç
3. Token'ı kopyala ve şifre yerine kullan

### 9. Kontrol Et

```bash
# Remote repository'yi kontrol et
git remote -v

# Son commit'i kontrol et
git log --oneline -1
```

## 🔄 Sonraki Push'lar İçin

Artık sadece şunları yapman yeterli:

```bash
git add .
git commit -m "Commit mesajı"
git push
```

## ⚠️ Sorun Giderme

### "fatal: not a git repository"
```bash
git init
```

### "remote origin already exists"
```bash
git remote remove origin
git remote add origin https://github.com/KULLANICI_ADI/dotcat.git
```

### "Permission denied"
- GitHub kullanıcı adı ve Personal Access Token'ı kontrol et
- SSH kullanıyorsan SSH key'lerini kontrol et

### Firebase Config Dosyaları Hala Görünüyorsa
```bash
# .gitignore'ı kontrol et
cat .gitignore | grep GoogleService

# Eğer yoksa ekle
echo "**/GoogleService-Info.plist" >> .gitignore
echo "**/google-services.json" >> .gitignore

# Git cache'i temizle
git rm -r --cached .
git add .
git commit -m "Update .gitignore to exclude Firebase config files"
```

## 📝 Örnek Tam Komut Dizisi

```bash
# 1. Git başlat
git init

# 2. Dosyaları ekle
git add .

# 3. Kontrol et
git status

# 4. Commit yap
git commit -m "Initial commit: Dotcat PetCare App v1.0.0"

# 5. Remote ekle (KULLANICI_ADI'ni değiştir)
git remote add origin https://github.com/KULLANICI_ADI/dotcat.git

# 6. Branch ayarla
git branch -M main

# 7. Push et
git push -u origin main
```

## ✅ Başarılı Push Sonrası

GitHub repository sayfasında tüm dosyalarını göreceksin. Firebase config dosyaları görünmemeli!

