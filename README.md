> 🚧 **Durum: aktif geliştirme.** Yazarın kullanımında çalışır; arayüzler değişebilir.

# Model Laboratuvarı — şema ve konuşmacı ayrımı adayı

Bu bir şema ve konuşmacı ayrımı denetimi teknik adayıdır. Model eğitimi, ses işleme veya gerçek veri kümesi değildir. Faz 0 araştırma kararları deney sonucu veya performans ölçümü değildir.

## İçerik ve haklar

- `schema/laboratory.sql`: kullanıcının yerel Model Laboratuvarı projesindeki şemanın kopyası.
- `speaker_split.py`: aday için yeni yazılmış denetim; `tests/test_speaker_split.py`: gerçek şemayı bellekte kuran sentetik örnekler.
- `README.en.md`: İngilizce açıklama; `MANIFEST.sha256`: tam dosya izin listesi ve kendi dışındaki dosyaların SHA256 değerleri. Manifest kendini içerir ama kendi özeti hesaplanamaz; işaretli istisnadır.

Kullanıcı kendi özgün kaynak ve belgelerinin yayımlanmasına izin verdi; bu katkılar [MIT lisansı](LICENSE) kapsamındadır. `KemalG-u` sahibinin kamusal takma adıdır. Bu izin üçüncü taraf haklarını kapsamaz; üçüncü taraf haklarının kapsamı bağımsız olarak doğrulanmış değildir. Python ve SQLite çalışma zamanları ayrı dağıtılır ve kendi lisanslarına tabidir. Başvurular: [Python sqlite3](https://docs.python.org/3/library/sqlite3.html); [SQLite CREATE TABLE](https://www.sqlite.org/lang_createtable.html); [SQLite foreign keys](https://www.sqlite.org/foreignkeys.html). Bu bağlantılar belge başvurularıdır, paketlenmiş kaynak değildir. Araştırma dosyaları, gerçek ses/veri, mevcut veritabanı, sırlar ve oturum dosyaları bu adayın kapsamında değildir.

## Denetim ve sınırlar

`find_speaker_leaks(connection)`, `samples` ve `split_groups` tablolarını birlikte okur; aynı birebir `speaker_id` train/development/test içinde birden çok bölüme atanmışsa kimlik ve sıralı bölümleri döndürür. Bu çıktı hassas olabilir; paylaşmayın. `require_speaker_isolation(connection)` aynı durumda kimliği içermeyen `ValueError` üretir. Boş/yalnız boşluk kimlik ve bilinmeyen bölüm hata verir. `quarantine` ve `NULL` bölüm ayrım hesabına katılmaz. Kimlikler kırpılmadan ve büyük/küçük harfe duyarlı karşılaştırılır: farklı kimliklerin aynı kişiye ait olup olmadığı anlaşılmaz. Boş veritabanının geçmesi veri kümesinin hazır olduğu anlamına gelmez.

SQL `uq_split_group_tuple` yalnız konuşmacı+oturum+kaynak üçlüsünü `split_groups` içinde tekilleştirir; farklı oturumdaki aynı konuşmacının bölümler arasında bulunmasını engellemez. `samples` kimlik alanlarının UPDATE işlemini, referans sürümlerinin UPDATE işlemini engelleyen tetikleyiciler vardır; referans DELETE işlemini engellemez. SQL bölüm adlarını kontrol eder ve bağlantıda foreign key etkinleştirildiğinde ilişkileri uygular; yeni bağlantılarda foreign key ayarı ayrıca yapılmalıdır. `split_locked` alanı tek başına kilit uygulamaz. Şema, iki tablo arasında atamaların tutarlılığını, konuşmacı/oturum/kaynağın ayrı ayrı bölünmemesini, aynı sesin tekrarını veya gerçek izinleri garanti etmez.

Denetim bir SQL tetikleyicisi değildir; açıkça çağrılmadıkça koruma sağlamaz. Oturum ve kaynak ayrımını, aynı sesin farklı kimlikle tekrarını, izinleri veya insan kimliğini doğrulamaz; `quarantine`/atanmamış kayıtlar üzerinde eğitim yapılmadığını da kontrol etmez. Üretim hattı veri kullanmadan hemen önce yetkili, tutarlı bir okuma anlık görüntüsünde denetimi çağırmalı ve sonrasında değişikliklerin sonucu geçersiz kılmasını ayrıca önlemelidir. Bağlantıyı işlev değil çağıran açar; işlev yazma yapmaz.

## Testler ve bekleyen çalışmalar

Bu adayda 12 sentetik test geçti. Bu sonuç o çalıştırmaya aittir; test sayısı ve sonuçlar zamanla değişebilir. Tekrar çalıştırmak için bu klasörde yalnız standart kütüphane ile:

```bash
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s tests -v
```

Windows PowerShell'de ortam değişkenini `$env:PYTHONDONTWRITEBYTECODE='1'` ile ayarlayın. Testler SQLite'ı yalnız bellekte açar, ses kullanmaz. Gerçek veriyle doğrulama ve performans testleri yapılmadı; sentetik testlerin geçmesi bunların yerine geçmez. 
