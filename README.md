# Ağ Yönlendirme Projesi

## Proje Amacı

Bu proje BSM317/BSM307 kodlu Bilgisayar Ağları dersi kapsamında ortaya çıkmıştır.
Bu projenin temel amacı, 250 düğümlü karmaşık bir ağ topolojisi üzerinde, servis kalitesi (QoS) parametrelerini optimize ederek kaynak ve hedef arasında en uygun rotayı bulan bir sistem geliştirmektir. Proje kapsamında gecikmenin minimize edilmesi, güvenilirliğin maksimize edilmesi ve ağ kaynak kullanımının optimize edilmesi hedeflenmiştir. Bu çok amaçlı optimizasyon problemini çözmek için Genetik Algoritma (GA) ve Karınca Kolonisi Optimizasyonu (ACO) yöntemleri karşılaştırmalı olarak uygulanmıştır.

## Katkıda Bulunanlar

* İmge Hamzaçebi
* Havva Yalçın
* Ezgi Atar
* Muhammet Aziz Atalay
* Batuhan Kantarcı
* Dilara Çınar
* Arda Gonca
* Ahmed Zahid Çelik

## Nasıl İndirilir ve Çalıştırılır?

Bu proje Windows işletim sistemi üzerinde test edilmiş ve çalıştırılmıştır. Diğer platformlarda uyumluluk garanti edilmemektedir.

### Ön Gereksinimler

*   **Flutter SDK:** `>=3.18.0-18.0.pre.54` sürümünü veya daha yenisini indirin ve kurun. Detaylı kurulum yönergeleri için [Flutter resmi web sitesini](https://flutter.dev/docs/get-started/install) ziyaret edebilirsiniz.
*   **Python:** Python 3.15 sürümünü indirin ve kurun. [Python resmi web sitesini](https://www.python.org/downloads/) ziyaret edebilirsiniz.

### Kurulum Adımları

1.  Projeyi kopyalayın:
    ```bash
    git clone https://github.com/woshiahmedc/CompNetwork_Project.git
    cd CompNetwork_Project
    ```

2.  Flutter bağımlılıklarını yükleyin:
    ```bash
    flutter pub get
    ```

3.  Python sanal ortamını oluşturun ve bağımlılıkları yükleyin:
    ```bash
    cd scripts
    python -m venv .venv
    .venv\Scripts\activate
    pip install -r requirements.txt
    deactivate
    cd ..
    ```

4.  Flutter uygulamasını derleyin (sadece Windows):
    ```bash
    flutter build windows
    ```

### Uygulamayı Çalıştırma

1.  Uygulamayı çalıştırmak için Flutter projesinin ana dizininde aşağıdaki komutu kullanın:
    ```bash
    flutter run
    ```
    Veya, derlenmiş Windows uygulamasını `build/windows/runner/Release` dizini altında bulabilirsiniz.

**Önemli Not:** Bu proje sadece Windows ortamında test edilmiş ve doğrulanmıştır. Diğer platformlarda beklenmedik davranışlar veya hatalar meydana gelebilir.
