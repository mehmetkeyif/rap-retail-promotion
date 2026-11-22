"! <p>Fiyat stratejisi: YÜZDE İNDİRİM (kampanya tipi P)</p>
"! Etkin fiyat = normal fiyat × (100 − indirim %) / 100
CLASS zcl_prm_strategy_pct_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " Bu sınıf arayüzdeki sözleşmeyi uygular.
    " Arayüzün tüm metotlarını IMPLEMENTATION bölümünde yazmak ZORUNDA.
    INTERFACES zif_prm_price_strategy_mk.
ENDCLASS.



CLASS zcl_prm_strategy_pct_mk IMPLEMENTATION.

  METHOD zif_prm_price_strategy_mk~get_effective_price.
    " Arayüz metodunun adı: arayüz_adı~metot_adı
    " Hesap packed (P) tiplerle yapılır; sonuç 2 ondalıklı rv_price'a
    " atanırken ticari yuvarlama uygulanır (AMDP'deki ROUND(...,2) ile aynı).
    rv_price = is_item-regular_price * ( 100 - is_item-discount_pct ) / 100.
  ENDMETHOD.

  METHOD zif_prm_price_strategy_mk~get_description.
    rv_text = |Yüzde indirim|.
  ENDMETHOD.

ENDCLASS.
