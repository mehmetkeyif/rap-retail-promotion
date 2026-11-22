"! <p>Fiyat stratejisi: X AL Y ÖDE (kampanya tipi B)</p>
"! Etkin birim fiyat = normal fiyat × Y / X
"! Örnek: 3 al 2 öde → 54,90 × 2 / 3 = 36,60
CLASS zcl_prm_strategy_bxgy_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_prm_price_strategy_mk.

    "! Kurucu metot: nesne oluşturulurken (NEW) otomatik çalışır
    "! @parameter iv_buy | Kaç adet alınıyor (X) - varsayılan 3
    "! @parameter iv_pay | Kaç adet ödeniyor (Y) - varsayılan 2
    METHODS constructor
      IMPORTING iv_buy TYPE i DEFAULT 3
                iv_pay TYPE i DEFAULT 2.

  PRIVATE SECTION.
    " Nesne özellikleri (attribute): her nesnenin kendi değeri olur
    " m = member (nesneye ait) önekiyle adlandırılır
    DATA mv_buy TYPE i.
    DATA mv_pay TYPE i.
ENDCLASS.



CLASS zcl_prm_strategy_bxgy_mk IMPLEMENTATION.

  METHOD constructor.
    " Parametreleri nesnenin kendi alanlarına sakla
    " me-> : "bu nesnenin" anlamına gelir
    me->mv_buy = iv_buy.
    me->mv_pay = iv_pay.
  ENDMETHOD.

  METHOD zif_prm_price_strategy_mk~get_effective_price.
    " Sıfıra bölme koruması: X hatalıysa indirimsiz fiyat döner
    IF mv_buy <= 0.
      rv_price = is_item-regular_price.
      RETURN.
    ENDIF.

    " Normal fiyat × ödenen / alınan (sonuç 2 ondalığa yuvarlanır)
    rv_price = is_item-regular_price * mv_pay / mv_buy.
  ENDMETHOD.

  METHOD zif_prm_price_strategy_mk~get_description.
    " String template içinde değişken: { mv_buy }
    rv_text = |{ mv_buy } al { mv_pay } öde|.
  ENDMETHOD.

ENDCLASS.
