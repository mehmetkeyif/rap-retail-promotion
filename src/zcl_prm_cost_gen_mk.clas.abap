"! <p>Ürünlere maliyet fiyatı yazar (kârlılık çalışması için test verisi)</p>
"! Çalıştırma: sınıf açıkken F9
CLASS zcl_prm_cost_gen_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " F9 ile çalıştırılabilen sınıflar bu arayüzü uygular
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    " Ürün -> maliyet oranı (maliyet = normal fiyat × oran)
    TYPES: BEGIN OF ty_ratio,
             product_id TYPE zprm_prod_mk-product_id,
             ratio      TYPE p LENGTH 3 DECIMALS 2,
           END OF ty_ratio,
           tt_ratio TYPE SORTED TABLE OF ty_ratio WITH UNIQUE KEY product_id.
ENDCLASS.



CLASS zcl_prm_cost_gen_mk IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " ---- 1) Maliyet oranları ----
    " Oranları bilerek farklı seçtik ki her durum ortaya çıksın:
    "   %20 indirimde P0003 (0.85) ve P0008 (0.90) ZARARA düşer (LOSS),
    "   P0010 (0.75) DÜŞÜK marjda kalır (LOW), diğerleri normal (OK).
    DATA(lt_ratio) = VALUE tt_ratio(
      ( product_id = 'P0001' ratio = '0.60' )
      ( product_id = 'P0002' ratio = '0.55' )
      ( product_id = 'P0003' ratio = '0.85' )
      ( product_id = 'P0004' ratio = '0.50' )
      ( product_id = 'P0005' ratio = '0.65' )
      ( product_id = 'P0006' ratio = '0.70' )
      ( product_id = 'P0007' ratio = '0.45' )
      ( product_id = 'P0008' ratio = '0.90' )
      ( product_id = 'P0009' ratio = '0.60' )
      ( product_id = 'P0010' ratio = '0.75' ) ).

    " ---- 2) Ürünleri oku ----
    SELECT product_id, base_price
      FROM zprm_prod_mk
      INTO TABLE @DATA(lt_products).

    " ---- 3) Her ürün için maliyeti hesapla ve yaz ----
    DATA lv_updated TYPE i.

    LOOP AT lt_products INTO DATA(ls_product).

      " Oran tablosunda bu ürün var mı? Yoksa atla.
      " (line_exists: satır var mı kontrolü - yeni söz dizimi)
      IF NOT line_exists( lt_ratio[ product_id = ls_product-product_id ] ).
        CONTINUE.
      ENDIF.

      " Maliyet = normal fiyat × oran
      " CONV: sonucu hedef alanın tipine çevirir (2 ondalık, otomatik yuvarlama)
      DATA(lv_cost) = CONV zprm_prod_mk-cost_price(
                        ls_product-base_price * lt_ratio[ product_id = ls_product-product_id ]-ratio ).

      UPDATE zprm_prod_mk
        SET cost_price = @lv_cost
        WHERE product_id = @ls_product-product_id.

      lv_updated += sy-dbcnt.   " güncellenen satır sayısını topla

      out->write( |{ ls_product-product_id }: fiyat { ls_product-base_price } -> maliyet { lv_cost }| ).
    ENDLOOP.

    out->write( |Toplam { lv_updated } ürün güncellendi.| ).

  ENDMETHOD.

ENDCLASS.
