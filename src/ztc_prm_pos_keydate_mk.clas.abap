"! <p>CDS birim testi: ZI_PRM_POS_KEYDATE_MK</p>
"! Görünümün okuduğu tablolar test dublörleriyle değiştirilir,
"! gerçek veriye dokunulmaz.
"!@testing ZI_PRM_POS_KEYDATE_MK
CLASS ztc_prm_pos_keydate_mk DEFINITION
  PUBLIC FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    " Test ortamı tüm testler için bir kez kurulur (CLASS-DATA)
    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    " Testlerde kullanacağımız sabit UUID'ler (16 baytlık hex değerler)
    CONSTANTS:
      c_promo_pub  TYPE sysuuid_x16 VALUE '00000000000000000000000000000001', " yayında (X)
      c_promo_new  TYPE sysuuid_x16 VALUE '00000000000000000000000000000002', " yeni (N)
      c_item_pub   TYPE sysuuid_x16 VALUE '000000000000000000000000000000A1',
      c_item_new   TYPE sysuuid_x16 VALUE '000000000000000000000000000000A2'.

    " ---- Kurulum / temizlik metotları (ABAP Unit bunları otomatik çağırır) ----
    CLASS-METHODS class_setup.     " tüm testlerden ÖNCE 1 kez
    CLASS-METHODS class_teardown.  " tüm testlerden SONRA 1 kez
    METHODS setup.                 " HER testten önce

    " ---- Yardımcı: test verisini dublör tablolara ekler ----
    METHODS insert_data.

    " ---- Testler ----
    METHODS only_published_promos   FOR TESTING.
    METHODS days_left_and_urgency   FOR TESTING.
    METHODS outside_validity_empty  FOR TESTING.
ENDCLASS.



CLASS ztc_prm_pos_keydate_mk IMPLEMENTATION.

  METHOD class_setup.
    " Test edilen görünümü veriyoruz.
    " Ortam, görünümün okuduğu tabloları (zprm_promo_mk, zprm_pitem_mk)
    " otomatik bulur ve yerlerine boş dublör tablolar koyar.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_PRM_POS_KEYDATE_MK' ).
  ENDMETHOD.


  METHOD class_teardown.
    " Dublörleri kaldır, sistemi eski haline getir
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    " Her test temiz başlasın: dublör tabloları boşalt, veriyi yeniden ekle
    go_env->clear_doubles( ).
    insert_data( ).
  ENDMETHOD.


  METHOD insert_data.
    " ---- Kampanya başlıkları ----
    " Tarihler sabit: test 'bugün'e bağlı değil, tarihi parametreyle veriyoruz
    DATA lt_promo TYPE STANDARD TABLE OF zprm_promo_mk WITH EMPTY KEY.
    lt_promo = VALUE #(
      " 1) Yayında (X) - 10..16 Kasım - görünümde GÖRÜNMELİ
      ( promo_uuid = c_promo_pub  promo_id = 'TEST0001' description = 'Published promo'
        promo_type = 'P' status = 'X' valid_from = '20261110' valid_to = '20261116'
        currency_code = 'TRY' )
      " 2) Yeni (N) - aynı tarihler - görünümde GÖRÜNMEMELİ (status X değil)
      ( promo_uuid = c_promo_new  promo_id = 'TEST0002' description = 'New promo'
        promo_type = 'P' status = 'N' valid_from = '20261110' valid_to = '20261116'
        currency_code = 'TRY' ) ).

    " ---- Kampanya kalemleri ----
    DATA lt_item TYPE STANDARD TABLE OF zprm_pitem_mk WITH EMPTY KEY.
    lt_item = VALUE #(
      " Yayındaki kampanyanın kalemi: 100 TL -> %20 -> 80 TL (kazanç 20)
      ( item_uuid = c_item_pub  parent_uuid = c_promo_pub  product_id = 'P0001'
        regular_price = '100.00' promo_price = '80.00' discount_pct = '20.00'
        currency_code = 'TRY' )
      " Yeni kampanyanın kalemi
      ( item_uuid = c_item_new  parent_uuid = c_promo_new  product_id = 'P0002'
        regular_price = '50.00'  promo_price = '45.00' discount_pct = '10.00'
        currency_code = 'TRY' ) ).

    " Verileri dublör tablolara ekle (tablo tipine göre doğru dublöre gider)
    go_env->insert_test_data( i_data = lt_promo ).
    go_env->insert_test_data( i_data = lt_item ).
  ENDMETHOD.


  METHOD only_published_promos.
    " Anahtar tarih: 15 Kasım -> iki kampanya da tarih olarak geçerli,
    " ama yalnızca status = X olan gelmeli
    DATA lv_date TYPE d VALUE '20261115'.

    " Parametreli görünümü ABAP SQL'den çağırma: görünüm( parametre = değer )
    SELECT FROM zi_prm_pos_keydate_mk( p_keydate = @lv_date )
      FIELDS promoid
      INTO TABLE @DATA(lt_result).

    " Tam 1 satır gelmeli
    cl_abap_unit_assert=>assert_equals( act = lines( lt_result )
                                        exp = 1
                                        msg = 'Yalnızca yayındaki kampanya gelmeli' ).
    " O satır TEST0001 olmalı
    cl_abap_unit_assert=>assert_equals( act = lt_result[ 1 ]-promoid
                                        exp = 'TEST0001'
                                        msg = 'Yanlış kampanya geldi' ).
  ENDMETHOD.


  METHOD days_left_and_urgency.
    " 15 Kasım -> bitiş 16 Kasım -> 1 gün kaldı -> LAST_DAYS (<= 2)
    DATA lv_date TYPE d VALUE '20261115'.

    SELECT FROM zi_prm_pos_keydate_mk( p_keydate = @lv_date )
      FIELDS daysleft, urgency, savingamount
      INTO TABLE @DATA(lt_result).

    " Önce satır var mı kontrol et (yoksa lt_result[ 1 ] dump verir)
    cl_abap_unit_assert=>assert_not_initial( act = lt_result
                                             msg = 'Sonuç boş olmamalı' ).

    " Tarih fonksiyonu: dats_days_between( 15.11, 16.11 ) = 1
    cl_abap_unit_assert=>assert_equals( act = lt_result[ 1 ]-daysleft
                                        exp = 1
                                        msg = 'DaysLeft yanlış' ).
    " CASE ifadesi
    cl_abap_unit_assert=>assert_equals( act = lt_result[ 1 ]-urgency
                                        exp = 'LAST_DAYS'
                                        msg = 'Urgency yanlış' ).
    " Aritmetik: 100 - 80 = 20
    cl_abap_unit_assert=>assert_equals( act = lt_result[ 1 ]-savingamount
                                        exp = '20.00'
                                        msg = 'SavingAmount yanlış' ).
  ENDMETHOD.


  METHOD outside_validity_empty.
    " 25 Kasım -> kampanya 16 Kasım'da bitti -> sonuç BOŞ olmalı
    DATA lv_date TYPE d VALUE '20261125'.

    SELECT FROM zi_prm_pos_keydate_mk( p_keydate = @lv_date )
      FIELDS promoid
      INTO TABLE @DATA(lt_result).

    cl_abap_unit_assert=>assert_initial( act = lt_result
                                         msg = 'Geçerlilik dışında kayıt gelmemeli' ).
  ENDMETHOD.

ENDCLASS.
