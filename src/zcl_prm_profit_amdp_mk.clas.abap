"! <p>AMDP: Kampanya kalemi kârlılığını HANA'da (SQLScript ile) hesaplar</p>
"! CDS table function ZI_PRM_PROMO_PROFIT_TF verisini bu sınıf üretir.
CLASS zcl_prm_profit_amdp_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " Bu arayüz sınıfı "AMDP sınıfı" yapar: HANA'da çalışan metotlar içerebilir
    INTERFACES if_amdp_marker_hdb.

    " Table function'ı dolduran metot.
    " Parametreleri ve dönüş tipi table function tanımından otomatik gelir.
    CLASS-METHODS get_profitability
      FOR TABLE FUNCTION zi_prm_promo_profit_tf.
ENDCLASS.



CLASS zcl_prm_profit_amdp_mk IMPLEMENTATION.

  METHOD get_profitability
    BY DATABASE FUNCTION FOR HDB LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY
    USING zprm_pitem_mk zprm_promo_mk zprm_prod_mk.

    -- ============================================================
    -- METOT TANIMINDAKI EKLER:
    --   BY DATABASE FUNCTION : metot HANA icinde tablo donduren fonksiyon olur
    --   FOR HDB              : hedef veritabani HANA
    --   LANGUAGE SQLSCRIPT   : govde ABAP degil, SQLScript
    --   OPTIONS READ-ONLY    : yalnizca okur, veri degistirmez
    --   USING ...            : kullanilan tum tablolar listelenmek ZORUNDA
    --
    -- DIKKAT: Buradan itibaren ABAP degil, SQLScript.
    -- Yorumlar iki tire ile yazilir. Her ifade noktali virgul ile biter.
    -- Yorumlarda tirnak isareti KULLANMA (ABAP derleyicisi karistirir).
    -- ============================================================

    -- 1) ARA SONUC: kalem + kampanya + urun maliyeti, etkin fiyat
    --    lt_base bir tablo degiskenidir (HANA belleginde gecici tablo)
    lt_base =
      SELECT i.client,
             i.item_uuid,
             h.promo_id,
             h.promo_type,
             i.product_id,
             CAST( i.regular_price AS DECIMAL(15,2) )            AS regular_price,
             CAST( i.promo_price   AS DECIMAL(15,2) )            AS promo_price,
             CAST( i.discount_pct  AS DECIMAL(5,2) )             AS discount_pct,
             -- maliyeti olmayan urun icin 0 (COALESCE: ilk bos olmayan deger)
             CAST( COALESCE( p.cost_price, 0 ) AS DECIMAL(15,2) ) AS cost_price,
             i.currency_code,
             -- Kampanya tipine gore ETKIN satis fiyati
             CAST(
               CASE h.promo_type
                 WHEN 'P' THEN ROUND( i.regular_price * ( 100 - i.discount_pct ) / 100, 2 )  -- yuzde indirim
                 WHEN 'F' THEN i.promo_price                                               -- sabit fiyat
                 WHEN 'B' THEN ROUND( i.regular_price * 2 / 3, 2 )                         -- 3 al 2 ode
                 ELSE i.promo_price
               END AS DECIMAL(15,2) )                            AS effective_price
        FROM zprm_pitem_mk AS i
        INNER JOIN zprm_promo_mk AS h
                ON h.client     = i.client
               AND h.promo_uuid = i.parent_uuid
        LEFT OUTER JOIN zprm_prod_mk AS p
                ON p.client     = i.client
               AND p.product_id = i.product_id
       -- yalnizca oturumdaki client verisi (SESSION_VARIABLE kurali)
       WHERE i.client = SESSION_CONTEXT( 'CDS_CLIENT' );

    -- 2) SONUC: marj, marj yuzdesi ve durum.
    --    Kolon sirasi table function tanimi ile AYNI olmali.
    --    Tablo degiskenini okurken basina iki nokta konur: :lt_base
    RETURN
      SELECT client,
             item_uuid,
             promo_id,
             promo_type,
             product_id,
             regular_price,
             promo_price,
             discount_pct,
             cost_price,
             effective_price,
             CAST( effective_price - cost_price AS DECIMAL(15,2) ) AS unit_margin,
             CAST(
               CASE WHEN effective_price = 0 THEN 0
                    ELSE ROUND( ( effective_price - cost_price ) * 100 / effective_price, 2 )
               END AS DECIMAL(7,2) )                              AS margin_pct,
             CASE WHEN effective_price - cost_price < 0 THEN 'LOSS'
                  WHEN effective_price = 0
                    OR ( effective_price - cost_price ) * 100 / effective_price < 10 THEN 'LOW'
                  ELSE 'OK'
             END                                                   AS profit_status,
             currency_code
        FROM :lt_base;

  ENDMETHOD.

ENDCLASS.
