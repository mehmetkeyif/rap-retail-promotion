"! <p>Kampanya fiyat stratejisi (Strategy deseni)</p>
"! Her kampanya tipi (P, F, B) bu arayüzü uygulayan ayrı bir sınıftır.
"! Hesap motoru, hangi sınıfla çalıştığını bilmeden yalnızca bu arayüzü kullanır.
INTERFACE zif_prm_price_strategy_mk
  PUBLIC.

  " ---- Ortak tipler ----
  " Arayüzde tanımlanan tipleri, uygulayan tüm sınıflar ortak kullanır
  " Tutar: 15 hane, 2 ondalık (AMDP'deki DECIMAL(15,2) ile aynı)
  TYPES ty_amount  TYPE p LENGTH 8 DECIMALS 2.
  " Yüzde: 5 hane, 2 ondalık (DECIMAL(5,2) ile aynı)
  TYPES ty_percent TYPE p LENGTH 3 DECIMALS 2.

  " Hesap için gereken kalem bilgileri
  TYPES: BEGIN OF ty_item,
           promo_type    TYPE c LENGTH 1,   " P / F / B
           regular_price TYPE ty_amount,    " normal fiyat
           promo_price   TYPE ty_amount,    " kalemde kayıtlı kampanya fiyatı
           discount_pct  TYPE ty_percent,   " indirim yüzdesi
         END OF ty_item.

  " ---- Sözleşme: her strateji bu iki metodu sağlamak ZORUNDA ----

  "! Kampanya tipine göre etkin (gerçek) birim satış fiyatı
  "! @parameter is_item  | Kalem bilgileri
  "! @parameter rv_price | Etkin fiyat
  METHODS get_effective_price
    IMPORTING is_item         TYPE ty_item
    RETURNING VALUE(rv_price) TYPE ty_amount.

  "! Stratejinin kısa açıklaması (raporlarda göstermek için)
  METHODS get_description
    RETURNING VALUE(rv_text) TYPE string.

ENDINTERFACE.
