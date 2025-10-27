# Paywall ve RevenueCat Kurulum Rehberi

Bu rehber, Varlık Takibi uygulamasına eklenen Paywall ve Premium abonelik sisteminin kurulumunu açıklar.

## 📋 Genel Bakış

Eklenen özellikler:
- ✅ RevenueCat entegrasyonu
- ✅ Paywall ekranı (aylık ve yıllık abonelikler)
- ✅ Premium kullanıcılar için reklam kaldırma
- ✅ Settings ekranında Premium butonu
- ✅ Otomatik abonelik yönetimi

## 🚀 Kurulum Adımları

### 1. RevenueCat SDK'yı Projeye Ekle

Xcode'da:
1. **File > Add Package Dependencies** menüsüne git
2. Arama kutusuna şunu gir: `https://github.com/RevenueCat/purchases-ios.git`
3. Version: **5.0.0** veya daha yeni bir versiyon seç
4. **Add Package** butonuna tıkla
5. **RevenueCat** kütüphanesini seç ve **Add Package** ile onayla

### 2. RevenueCat Hesabı Oluştur

1. [RevenueCat Dashboard](https://app.revenuecat.com)'a git
2. Yeni hesap oluştur veya giriş yap
3. **Projects** bölümünden yeni bir proje oluştur

### 3. iOS Uygulamasını RevenueCat'e Ekle

1. Dashboard'da **Apps** sekmesine git
2. **+ New App** butonuna tıkla
3. Uygulama bilgilerini gir:
   - **App Name**: Varlık Takibi
   - **Bundle ID**: `com.xptapps.assetbook`
   - **Platform**: iOS
4. **Apple App Store** ile bağlantı kur:
   - App Store Connect'ten **In-App Purchase Key** oluştur
   - Key'i RevenueCat'e yükle

### 4. Ürünleri (Products) Oluştur

#### App Store Connect'te:
1. [App Store Connect](https://appstoreconnect.apple.com)'e git
2. **My Apps > Varlık Takibi > In-App Purchases** bölümüne git
3. İki adet **Auto-Renewable Subscription** oluştur:

**Aylık Abonelik:**
- Product ID: `com.xptapps.assetbook.premium.monthly`
- Reference Name: `Premium Monthly`
- Subscription Group: `Premium` (yeni oluştur)
- Subscription Duration: `1 Month`
- Price: `₺49,99`

**Yıllık Abonelik:**
- Product ID: `com.xptapps.assetbook.premium.yearly`
- Reference Name: `Premium Yearly`
- Subscription Group: `Premium` (aynı grup)
- Subscription Duration: `1 Year`
- Price: `₺299,99`

#### RevenueCat Dashboard'da:
1. **Products** sekmesine git
2. **+ New** butonuna tıkla
3. Her iki ürünü de ekle:
   - App Store Connect'teki Product ID'leri kullan
   - Type: **Subscription** seç

### 5. Entitlement Oluştur

1. RevenueCat Dashboard'da **Entitlements** sekmesine git
2. **+ New** butonuna tıkla
3. Entitlement bilgilerini gir:
   - **Identifier**: `premium`
   - **Description**: Premium features
4. Her iki ürünü de bu entitlement'a ekle

### 6. Offering Oluştur

1. **Offerings** sekmesine git
2. **Current Offering** oluştur veya düzenle
3. İki paket ekle:

**Aylık Paket:**
- Package ID: `monthly`
- Product: `com.xptapps.assetbook.premium.monthly`

**Yıllık Paket:**
- Package ID: `annual`
- Product: `com.xptapps.assetbook.premium.yearly`

### 7. API Key'i Projeye Ekle

1. RevenueCat Dashboard'da **API Keys** bölümüne git
2. **Public App-Specific API Keys** kısmından iOS key'ini kopyala
3. `MyGolds/App/MyGoldsApp.swift` dosyasını aç
4. Şu satırı bul:
   ```swift
   let revenueCatAPIKey = "REVENUECAT_API_KEY_BURAYA"
   ```
5. `"REVENUECAT_API_KEY_BURAYA"` yerine kopyaladığın API key'i yapıştır:
   ```swift
   let revenueCatAPIKey = "appl_xxxxxxxxxxxxxxxxx"
   ```

### 8. Test Kullanıcısı Ekle (İsteğe Bağlı)

1. RevenueCat Dashboard'da **Customer Lists** > **Testers** bölümüne git
2. Test kullanıcılarını ekle (email veya App User ID)
3. Sandbox ortamında test satın alımları yap

## 🎨 Eklenen Dosyalar

### Yeni Dosyalar:
- `MyGolds/Utils/Helpers/RevenueCat/RevenueCatManager.swift` - RevenueCat işlemlerini yöneten manager
- `MyGolds/Models/SubscriptionProduct.swift` - Abonelik ürün modeli
- `MyGolds/Presentation/Views/Paywall/PaywallView.swift` - Paywall UI ekranı

### Güncellenen Dosyalar:
- `MyGolds/App/MyGoldsApp.swift` - RevenueCat başlatma
- `MyGolds/Utils/Helpers/Admob/AdmobManager.swift` - Premium kontrolü
- `MyGolds/Utils/Helpers/Admob/AppOpenAdManager.swift` - Premium kontrolü
- `MyGolds/Presentation/Views/Settings/SettingsView.swift` - Premium butonu

## 🧪 Test Etme

### Sandbox Test:
1. iOS cihazda **Settings > App Store > Sandbox Account** bölümüne git
2. Test Apple ID ile giriş yap
3. Uygulamayı çalıştır
4. **Settings > Premium'a Yükselt** butonuna tıkla
5. Paywall ekranında ürün seç ve satın al
6. Sandbox hesabı ile onayla

### Doğrulama:
- ✅ Satın alım sonrası reklamlar gizlenmeli
- ✅ Settings'te "Premium Üye" badge görünmeli
- ✅ Premium banner gizlenmeli
- ✅ "Satın Alımları Geri Yükle" çalışmalı

## 📱 Kullanım

### Kullanıcı Akışı:
1. Kullanıcı Settings ekranına gider
2. "Premium'a Yükselt" butonuna veya Premium Banner'a tıklar
3. Paywall ekranı açılır
4. Aylık veya Yıllık paket seçer
5. "Premium'a Başla" butonuna tıklar
6. App Store satın alma akışı başlar
7. Başarılı satın alım sonrası:
   - Reklamlar otomatik gizlenir
   - Premium badge aktif olur
   - Banner değişir

### Premium Özellikleri:
- 🚫 Reklamların kaldırılması (Banner, Interstitial, App Open)
- ⚡ Gelecekte eklenecek premium özellikler için hazır altyapı

## 🔐 Güvenlik

### API Key Güvenliği:
- ⚠️ **ÖNEMLİ**: Production API key'i Git'e commit edilmemeli
- Şu yöntemlerden birini kullan:
  1. `.xcconfig` dosyası ile environment variables
  2. Build Phases script ile key enjeksiyonu
  3. CI/CD pipeline'da güvenli secret yönetimi

Örnek `.xcconfig`:
```
REVENUECAT_API_KEY = appl_xxxxxxxxxxxxxxxxx
```

Swift'te kullanım:
```swift
guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String else {
    fatalError("RevenueCat API Key not found")
}
RevenueCatManager.shared.configure(apiKey: apiKey)
```

## 📊 Analytics

RevenueCat otomatik olarak şunları takip eder:
- Subscription starts
- Renewals
- Cancellations
- Revenue
- Churn rate

Firebase Analytics ile entegre:
- `purchase_completed` eventi
- `product_id` ve `price` parametreleri

## 🐛 Sorun Giderme

### "No offerings found" hatası:
- RevenueCat Dashboard'da Offering doğru yapılandırıldı mı?
- API Key doğru mu?
- Products App Store Connect'te "Ready to Submit" durumunda mı?

### Test satın alımı tamamlanmıyor:
- Sandbox Apple ID kullanıyor musunuz?
- Cihazda production Apple ID'den çıkış yaptınız mı?
- App Store Connect'te In-App Purchases "Approved" durumunda mı?

### Reklamlar hala görünüyor:
- `RevenueCatManager.shared.isPremium` durumu kontrol edin
- Customer Info başarıyla alınıyor mu?
- Entitlement identifier doğru mu? (`premium`)

## 📚 Kaynaklar

- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [iOS Quick Start](https://docs.revenuecat.com/docs/ios)
- [App Store Connect Guide](https://developer.apple.com/app-store/subscriptions/)
- [Testing Subscriptions](https://docs.revenuecat.com/docs/sandbox)

## 🎯 Production Checklist

Yayına almadan önce:
- [ ] RevenueCat API Key güvenli şekilde eklendi
- [ ] App Store Connect'te ürünler "Ready for Sale" durumunda
- [ ] RevenueCat Dashboard production yapılandırması tamamlandı
- [ ] Sandbox testleri başarılı
- [ ] Privacy Policy güncellendi (abonelik şartları)
- [ ] App Store submission'da "In-App Purchases" bölümü dolduruldu
- [ ] Screenshots ve demo video hazırlandı (gerekirse)

## 💰 Fiyatlandırma Stratejisi

Mevcut Fiyatlar:
- **Aylık**: ₺49,99
- **Yıllık**: ₺299,99 (Ayda ~₺25, %50 tasarruf)

Bu fiyatlar App Store Connect'te kolayca değiştirilebilir.

---

**Not**: Bu kurulum tamamlandığında, uygulama tam fonksiyonel bir Paywall sistemi ile çalışacaktır. RevenueCat, abonelik yönetimini, receipt validation'ı ve cross-platform senkronizasyonu otomatik olarak halleder.
