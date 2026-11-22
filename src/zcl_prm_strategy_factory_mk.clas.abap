"! <p>Factory: kampanya tipine göre doğru fiyat stratejisini üretir</p>
"! Yeni bir kampanya tipi eklendiğinde yalnızca yeni strateji sınıfı
"! yazılır ve buraya TEK satır eklenir; hesap motoru değişmez.
CLASS zcl_prm_strategy_factory_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    "! Kampanya tipine uygun stratejiyi döndürür
    "! @parameter iv_promo_type | P = yüzde, F = sabit fiyat, B = 3 al 2 öde
    "! @parameter ro_strategy   | Strateji nesnesi (dönüş tipi ARAYÜZ referansı)
    CLASS-METHODS get_strategy
      IMPORTING iv_promo_type      TYPE zif_prm_price_strategy_mk=>ty_item-promo_type
      RETURNING VALUE(ro_strategy) TYPE REF TO zif_prm_price_strategy_mk.
ENDCLASS.



CLASS zcl_prm_strategy_factory_mk IMPLEMENTATION.

  METHOD get_strategy.
    " SWITCH: değere göre sonuç üreten ifade (yeni söz dizimi; CASE'in ifade hali)
    " NEW:    nesne oluşturur (eski söz dizimindeki CREATE OBJECT)
    " Dönüş tipi arayüz olduğu için her strateji nesnesi buraya atanabilir.
    " Buna "upcast" denir: somut sınıf, arayüz referansı olarak görülür.
    ro_strategy = SWITCH #( iv_promo_type
                    WHEN 'P' THEN NEW zcl_prm_strategy_pct_mk( )
                    WHEN 'B' THEN NEW zcl_prm_strategy_bxgy_mk( iv_buy = 3 iv_pay = 2 )
                    " F ve tanımsız tipler: sabit fiyat (AMDP'deki ELSE ile aynı)
                    ELSE          NEW zcl_prm_strategy_fix_mk( ) ).
  ENDMETHOD.

ENDCLASS.
