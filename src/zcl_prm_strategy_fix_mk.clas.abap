"! <p>Fiyat stratejisi: SABİT FİYAT (kampanya tipi F)</p>
"! Etkin fiyat = kalemde kayıtlı kampanya fiyatı (olduğu gibi)
"! Tanımsız kampanya tipleri için de bu strateji kullanılır (AMDP'deki ELSE ile aynı).
CLASS zcl_prm_strategy_fix_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prm_price_strategy_mk.
ENDCLASS.



CLASS zcl_prm_strategy_fix_mk IMPLEMENTATION.

  METHOD zif_prm_price_strategy_mk~get_effective_price.
    " Sabit fiyatlı kampanyada hesap yok: kayıtlı fiyat aynen kullanılır
    rv_price = is_item-promo_price.
  ENDMETHOD.

  METHOD zif_prm_price_strategy_mk~get_description.
    rv_text = |Sabit fiyat|.
  ENDMETHOD.

ENDCLASS.
