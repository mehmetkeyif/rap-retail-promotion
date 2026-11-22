"! <p>Kampanya kârlılık motoru (ABAP Objects)</p>
"! AMDP ile aynı hesabı ABAP tarafında, Strategy deseniyle yapar.
"! F9 ile çalıştırınca iki motorun sonuçlarını karşılaştırır.
CLASS zcl_prm_profit_calc_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    " Arayüzdeki tipleri kısa adla kullanmak için takma ad (alias) tipler
    TYPES ty_amount  TYPE zif_prm_price_strategy_mk=>ty_amount.
    TYPES ty_item    TYPE zif_prm_price_strategy_mk=>ty_item.

    " Tek bir kalemin hesap sonucu
    TYPES: BEGIN OF ty_calc,
             effective_price TYPE ty_amount,
             unit_margin     TYPE ty_amount,
             margin_pct      TYPE p LENGTH 4 DECIMALS 2,   " DECIMAL(7,2) ile aynı
             profit_status   TYPE c LENGTH 4,               " LOSS / LOW / OK
             strategy        TYPE string,                   " hangi strateji kullanıldı
           END OF ty_calc.

    " Rapor satırı: kalem bilgisi + hesap sonucu
    TYPES: BEGIN OF ty_result,
             item_uuid  TYPE sysuuid_x16,
             promo_id   TYPE c LENGTH 10,
             product_id TYPE c LENGTH 10,
             promo_type TYPE c LENGTH 1,
             cost_price TYPE ty_amount.
             INCLUDE TYPE ty_calc.            " ty_calc alanlarını buraya ekle
    TYPES: END OF ty_result,
           tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    "! Tek bir kalemin kârlılığını hesaplar (veritabanına dokunmaz; birim testi kolay)
    "! @parameter is_item  | Kalem bilgileri
    "! @parameter iv_cost  | Birim maliyet
    "! @parameter rs_calc  | Hesap sonucu
    METHODS calculate_item
      IMPORTING is_item        TYPE ty_item
                iv_cost        TYPE ty_amount
      RETURNING VALUE(rs_calc) TYPE ty_calc.

    "! Tüm kampanya kalemlerini veritabanından okuyup hesaplar
    METHODS calculate_all
      RETURNING VALUE(rt_result) TYPE tt_result.
ENDCLASS.



CLASS zcl_prm_profit_calc_mk IMPLEMENTATION.

  METHOD calculate_item.
    " 1) Kampanya tipine göre stratejiyi al.
    "    Motor hangi sınıfla çalıştığını BİLMİYOR; yalnızca arayüzü kullanıyor.
    DATA(lo_strategy) = zcl_prm_strategy_factory_mk=>get_strategy( is_item-promo_type ).

    " 2) Etkin fiyat (polimorfizm: aynı çağrı, tipe göre farklı hesap)
    rs_calc-effective_price = lo_strategy->get_effective_price( is_item ).
    rs_calc-strategy        = lo_strategy->get_description( ).

    " 3) Birim marj
    rs_calc-unit_margin = rs_calc-effective_price - iv_cost.

    " 4) Marj yüzdesi (COND: koşula göre değer üreten ifade; sıfıra bölme koruması)
    rs_calc-margin_pct = COND #( WHEN rs_calc-effective_price = 0 THEN 0
                                 ELSE rs_calc-unit_margin * 100 / rs_calc-effective_price ).

    " 5) Durum. Yuvarlanmamış değerle karşılaştırıyoruz (AMDP ile aynı mantık):
    "    marj / fiyat < %10  <=>  marj × 100 < fiyat × 10   (bölme yok, hassas)
    rs_calc-profit_status = COND #(
      WHEN rs_calc-unit_margin < 0                                   THEN 'LOSS'
      WHEN rs_calc-effective_price = 0
        OR rs_calc-unit_margin * 100 < rs_calc-effective_price * 10  THEN 'LOW'
      ELSE 'OK' ).
  ENDMETHOD.


  METHOD calculate_all.
    " Kalem + kampanya başlığı + ürün maliyeti (AMDP'deki join'in ABAP SQL hali)
    SELECT i~item_uuid, h~promo_id, h~promo_type, i~product_id,
           i~regular_price, i~promo_price, i~discount_pct,
           p~cost_price
      FROM zprm_pitem_mk AS i
      INNER JOIN zprm_promo_mk AS h
              ON h~promo_uuid = i~parent_uuid
      LEFT OUTER JOIN zprm_prod_mk AS p
              ON p~product_id = i~product_id
      INTO TABLE @DATA(lt_data).

    LOOP AT lt_data INTO DATA(ls_data).
      " Kalem bilgisini strateji tipine dönüştür (aynı adlı alanlar kopyalanır)
      DATA(ls_item) = CORRESPONDING ty_item( ls_data ).

      " Hesapla
      DATA(ls_calc) = calculate_item( is_item = ls_item
                                      iv_cost = CONV #( ls_data-cost_price ) ).

      " Rapor satırını oluştur: önce kalem alanları, sonra hesap sonucu
      DATA(ls_result) = CORRESPONDING ty_result( ls_data ).
      ls_result = CORRESPONDING #( BASE ( ls_result ) ls_calc ).
      APPEND ls_result TO rt_result.
    ENDLOOP.

    " Kampanya ve ürüne göre sırala
    SORT rt_result BY promo_id product_id.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    " ---- 1) OO motoru ile hesapla ----
    DATA(lt_oo) = calculate_all( ).

    " ---- 2) AMDP motorunun sonuçlarını oku (table function'ı normal tablo gibi) ----
    SELECT item_uuid, effective_price, unit_margin, margin_pct, profit_status
      FROM zi_prm_promo_profit_tf
      INTO TABLE @DATA(lt_amdp).

    " ---- 3) Satır satır karşılaştır ----
    out->write( |Kampanya   Ürün   Tip  Strateji          Etkin   Marj    Marj%  Durum  AMDP| ).
    out->write( |-------------------------------------------------------------------------| ).

    DATA lv_match TYPE i.

    LOOP AT lt_oo INTO DATA(ls_oo).
      " AMDP'de aynı kalemi bul (VALUE #( ) OPTIONAL: bulunamazsa boş döner, dump vermez)
      DATA(ls_amdp) = VALUE #( lt_amdp[ item_uuid = ls_oo-item_uuid ] OPTIONAL ).

      " Dört değer de aynı mı?
      DATA(lv_same) = xsdbool( ls_amdp-effective_price = ls_oo-effective_price
                           AND ls_amdp-unit_margin     = ls_oo-unit_margin
                           AND ls_amdp-margin_pct      = ls_oo-margin_pct
                           AND ls_amdp-profit_status   = ls_oo-profit_status ).
      IF lv_same = abap_true.
        lv_match += 1.
      ENDIF.

      " WIDTH: sütun genişliği, ALIGN: hizalama (string template biçimlendirme)
      out->write( |{ ls_oo-promo_id WIDTH = 11 }{ ls_oo-product_id WIDTH = 7 }{ ls_oo-promo_type WIDTH = 5 }| &&
                  |{ ls_oo-strategy WIDTH = 16 }| &&
                  |{ ls_oo-effective_price WIDTH = 9 ALIGN = RIGHT }| &&
                  |{ ls_oo-unit_margin WIDTH = 8 ALIGN = RIGHT }| &&
                  |{ ls_oo-margin_pct WIDTH = 8 ALIGN = RIGHT }  | &&
                  |{ ls_oo-profit_status WIDTH = 6 }| &&
                  |{ COND string( WHEN lv_same = abap_true THEN 'AYNI' ELSE 'FARKLI' ) }| ).
    ENDLOOP.

    " ---- 4) Özet: REDUCE ile sayım (döngü yazmadan toplama) ----
    DATA(lv_loss) = REDUCE i( INIT n = 0
                              FOR r IN lt_oo WHERE ( profit_status = 'LOSS' )
                              NEXT n = n + 1 ).

    out->write( |-------------------------------------------------------------------------| ).
    out->write( |Toplam { lines( lt_oo ) } kalem, { lv_match } tanesi AMDP ile AYNI. Zararına satış: { lv_loss }| ).
  ENDMETHOD.

ENDCLASS.
