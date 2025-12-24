#!/bin/bash

# SSH Key ile GitHub Push Scripti
# Bu script SSH key oluşturur, GitHub'a eklemeniz için gösterir ve push eder

echo "🔑 SSH Key ile GitHub Push İşlemi"
echo "=================================="
echo ""

# 1. SSH key var mı kontrol et
if [ -f ~/.ssh/id_ed25519.pub ] || [ -f ~/.ssh/id_rsa.pub ]; then
    echo "✅ SSH key zaten mevcut!"
    if [ -f ~/.ssh/id_ed25519.pub ]; then
        KEY_FILE=~/.ssh/id_ed25519.pub
    else
        KEY_FILE=~/.ssh/id_rsa.pub
    fi
    echo ""
    echo "📋 Public key'iniz:"
    echo "----------------------------------------"
    cat $KEY_FILE
    echo "----------------------------------------"
    echo ""
    read -p "Bu key'i GitHub'a eklediniz mi? (y/n): " KEY_ADDED
    if [ "$KEY_ADDED" != "y" ] && [ "$KEY_ADDED" != "Y" ]; then
        echo ""
        echo "📝 GitHub'a ekleme adımları:"
        echo "1. https://github.com/settings/keys adresine gidin"
        echo "2. 'New SSH key' butonuna tıklayın"
        echo "3. Title: 'MacBook' (veya istediğiniz isim)"
        echo "4. Key: Yukarıdaki key'i kopyalayıp yapıştırın"
        echo "5. 'Add SSH key' butonuna tıklayın"
        echo ""
        read -p "Key'i ekledikten sonra Enter'a basın..."
    fi
else
    echo "🔨 SSH key oluşturuluyor..."
    echo ""
    read -p "GitHub email adresinizi girin: " GITHUB_EMAIL
    
    if [ -z "$GITHUB_EMAIL" ]; then
        echo "❌ Email adresi girilmedi. İşlem iptal edildi."
        exit 1
    fi
    
    # SSH key oluştur
    ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f ~/.ssh/id_ed25519 -N ""
    
    echo ""
    echo "✅ SSH key oluşturuldu!"
    echo ""
    echo "📋 Public key'iniz:"
    echo "----------------------------------------"
    cat ~/.ssh/id_ed25519.pub
    echo "----------------------------------------"
    echo ""
    echo "📝 Şimdi bu key'i GitHub'a ekleyin:"
    echo "1. https://github.com/settings/keys adresine gidin"
    echo "2. 'New SSH key' butonuna tıklayın"
    echo "3. Title: 'MacBook' (veya istediğiniz isim)"
    echo "4. Key: Yukarıdaki key'i kopyalayıp yapıştırın"
    echo "5. 'Add SSH key' butonuna tıklayın"
    echo ""
    read -p "Key'i ekledikten sonra Enter'a basın..."
fi

# 2. GitHub bağlantısını test et
echo ""
echo "🔍 GitHub bağlantısı test ediliyor..."
ssh -T git@github.com 2>&1 | head -3

# 3. GitHub kullanıcı adını sor
echo ""
read -p "👤 GitHub kullanıcı adınızı girin: " GITHUB_USERNAME

if [ -z "$GITHUB_USERNAME" ]; then
    echo "❌ Kullanıcı adı girilmedi. İşlem iptal edildi."
    exit 1
fi

# 4. Repository adını sor
read -p "📦 Repository adını girin (varsayılan: dotcat): " REPO_NAME
REPO_NAME=${REPO_NAME:-dotcat}

# 5. Remote ekle
echo ""
echo "🔗 Remote repository ekleniyor..."
git remote remove origin 2>/dev/null || true
git remote add origin "git@github.com:$GITHUB_USERNAME/$REPO_NAME.git"
echo "✅ Remote eklendi: git@github.com:$GITHUB_USERNAME/$REPO_NAME.git"

# 6. Branch'i main olarak ayarla
echo ""
echo "🌿 Branch 'main' olarak ayarlanıyor..."
git branch -M main
echo "✅ Branch 'main' olarak ayarlandı"

# 7. Push et
echo ""
echo "📤 GitHub'a push ediliyor..."
echo ""
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Başarılı! Repository GitHub'a yüklendi:"
    echo "   https://github.com/$GITHUB_USERNAME/$REPO_NAME"
else
    echo ""
    echo "❌ Push başarısız oldu."
    echo ""
    echo "💡 Kontrol edin:"
    echo "   - SSH key GitHub'a eklendi mi?"
    echo "   - GitHub'da repository oluşturuldu mu?"
    echo "   - Repository adı doğru mu?"
    exit 1
fi

