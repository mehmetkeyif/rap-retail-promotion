" ======================================================================
" BIRIM TESTLERI - Davranis metotlarini tek tek test eder
"
" Yontem: "Islem tamponu dublörü" (transactional buffer test double)
"  - Gercek RAP tamponu yerine sahte bir tampon kullanilir.
"  - Testte EML ile sahte tampona kampanya/kalem koyariz.
"  - Sonra dogrulama/aksiyon metodunu DOGRUDAN cagiririz.
"  - Metot icindeki READ ENTITIES ... IN LOCAL MODE sahte tampondan okur.
"  - Hicbir sey veritabanina yazilmaz.
" Isleyici siniflara erisim izni Local Types sekmesinde (FRIENDS) verildi.
"
" Cevap tipleri (RESPONSE FOR ...):
"  EARLY : etkilesim asamasi (aksiyonlar)
"  LATE  : kaydetme asamasi (dogrulamalar) ve bu sistemde belirlemeler
" ======================================================================
CLASS ltc_behavior DEFINITION FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    " Sahte RAP tamponu (is nesnesi icin)
    CLASS-DATA go_bo_env  TYPE REF TO if_botd_txbufdbl_bo_test_env.
    " Sahte tablolar (cakisma kontrolundeki SELECT'ler icin)
    CLASS-DATA go_sql_env TYPE REF TO if_osql_test_environment.

    " Test edilen nesneler ("class under test")
    DATA mo_cut_promo TYPE REF TO lhc_Promotion.
    DATA mo_cut_item  TYPE REF TO lhc_Item.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    " Yardimci: sahte tampona bir kampanya koy, anahtarini dondur
    METHODS add_promo
      IMPORTING iv_from        TYPE d
                iv_to          TYPE d
      RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.

    " Yardimci: sahte tampondaki bir kampanyaya kalem ekle
    METHODS add_item
      IMPORTING iv_promo_uuid  TYPE sysuuid_x16
                iv_product     TYPE zprm_pitem_mk-product_id
                iv_price       TYPE zprm_pitem_mk-regular_price
                iv_disc        TYPE zprm_pitem_mk-discount_pct
      RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.

    METHODS dates_end_before_start_fails FOR TESTING.
    METHODS dates_valid_range_passes     FOR TESTING.
    METHODS promo_price_is_calculated    FOR TESTING.
    METHODS approve_without_items_fails  FOR TESTING.
    METHODS overlap_is_detected          FOR TESTING.
ENDCLASS.


CLASS ltc_behavior IMPLEMENTATION.

  METHOD class_setup.
    " 1) Sahte RAP tamponu: ZR_PRM_PROMO_MK'ya yapilan EML erisimleri
    "    (testte ve test edilen kodda) bu sahte tampona gider.
    DATA(lo_config) = cl_botd_txbufdbl_bo_test_env=>prepare_environment_config(
                        )->set_bdef_dependencies( VALUE #( ( 'ZR_PRM_PROMO_MK' ) ) ).
    go_bo_env = cl_botd_txbufdbl_bo_test_env=>create( environment_config = lo_config ).

    " 2) Sahte tablolar: cakisma kontrolundeki SELECT'ler bunlari okur.
    go_sql_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZPRM_PROMO_MK' )
                                   ( 'ZPRM_PITEM_MK' )
                                   ( 'ZI_PRM_PRODUCT_MK' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_bo_env->destroy( ).
    go_sql_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    " Her test temiz baslasin
    go_bo_env->clear_doubles( ).
    go_sql_env->clear_doubles( ).

    " Isleyici siniflari olustur. FOR TESTING eki, normalde disaridan
    " olusturulamayan RAP isleyicilerini testte olusturmaya izin verir.
    CREATE OBJECT mo_cut_promo FOR TESTING.
    CREATE OBJECT mo_cut_item  FOR TESTING.
  ENDMETHOD.


  METHOD add_promo.
    " Sahte tampona bir kampanya koy (asil kayit, taslak degil).
    "  IN LOCAL MODE : readonly alanlari (PromoID, Status) doldurabilmek icin.
    "  PromoUUID'i VERMIYORUZ: "numbering : managed" oldugu icin anahtari
    "  RAP uretir. Uretilen anahtari MAPPED cevabindan aliyoruz.
    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        CREATE FIELDS ( PromoID Description PromoType
                        ValidFrom ValidTo Status CurrencyCode )
        WITH VALUE #( ( %cid         = 'P'
                        %is_draft    = if_abap_behv=>mk-off
                        PromoID      = 'PR00000077'
                        Description  = 'Unit Test Promo'
                        PromoType    = 'P'
                        ValidFrom    = iv_from
                        ValidTo      = iv_to
                        Status       = 'N'
                        CurrencyCode = 'TRY' ) )
      MAPPED DATA(ls_mapped).

    " MAPPED : "gecici ad (%cid) -> gercek anahtar" eslesmesi
    rv_uuid = ls_mapped-promotion[ 1 ]-PromoUUID.
  ENDMETHOD.


  METHOD add_item.
    " Kampanyanin altina kalem ekle.
    "  ItemUUID'i vermiyoruz (RAP uretir); RegularPrice ve CurrencyCode
    "  readonly oldugu icin yine IN LOCAL MODE kullaniyoruz.
    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        CREATE BY \_Item
        FIELDS ( ProductID RegularPrice DiscountPct CurrencyCode )
        WITH VALUE #( ( PromoUUID = iv_promo_uuid
                        %is_draft = if_abap_behv=>mk-off
                        %target   = VALUE #( ( %cid         = 'I'
                                               %is_draft    = if_abap_behv=>mk-off
                                               ProductID    = iv_product
                                               RegularPrice = iv_price
                                               DiscountPct  = iv_disc
                                               CurrencyCode = 'TRY' ) ) ) )
      MAPPED DATA(ls_mapped).

    rv_uuid = ls_mapped-item[ 1 ]-ItemUUID.
  ENDMETHOD.


  METHOD dates_end_before_start_fails.
    " Dogrulama: cevap tipleri LATE
    DATA ls_failed   TYPE RESPONSE FOR FAILED LATE zr_prm_promo_mk.
    DATA ls_reported TYPE RESPONSE FOR REPORTED LATE zr_prm_promo_mk.
    DATA lv_from     TYPE d.
    DATA lv_to       TYPE d.

    " GIVEN: bitis tarihi baslangictan 5 gun once
    lv_from = cl_abap_context_info=>get_system_date( ).
    lv_to   = lv_from - 5.
    DATA(lv_uuid) = add_promo( iv_from = lv_from iv_to = lv_to ).

    " WHEN: dogrulamayi dogrudan cagir
    mo_cut_promo->validatedates(
      EXPORTING keys     = VALUE #( ( PromoUUID = lv_uuid
                                      %is_draft = if_abap_behv=>mk-off ) )
      CHANGING  failed   = ls_failed
                reported = ls_reported ).

    " THEN: kampanya basarisiz isaretlenmeli
    cl_abap_unit_assert=>assert_not_initial(
      act = ls_failed-promotion
      msg = 'End date before start date must fail' ).
  ENDMETHOD.


  METHOD dates_valid_range_passes.
    DATA ls_failed   TYPE RESPONSE FOR FAILED LATE zr_prm_promo_mk.
    DATA ls_reported TYPE RESPONSE FOR REPORTED LATE zr_prm_promo_mk.
    DATA lv_from     TYPE d.
    DATA lv_to       TYPE d.

    " GIVEN: gecerli tarih araligi (7 gun)
    lv_from = cl_abap_context_info=>get_system_date( ).
    lv_to   = lv_from + 7.
    DATA(lv_uuid) = add_promo( iv_from = lv_from iv_to = lv_to ).

    " WHEN
    mo_cut_promo->validatedates(
      EXPORTING keys     = VALUE #( ( PromoUUID = lv_uuid
                                      %is_draft = if_abap_behv=>mk-off ) )
      CHANGING  failed   = ls_failed
                reported = ls_reported ).

    " THEN: hata olmamali
    cl_abap_unit_assert=>assert_initial(
      act = ls_failed-promotion
      msg = 'Valid date range must not fail' ).
  ENDMETHOD.


  METHOD promo_price_is_calculated.
    " Belirleme: bu sistemde cevap tipi LATE
    DATA ls_reported TYPE RESPONSE FOR REPORTED LATE zr_prm_promo_mk.
    DATA lv_from     TYPE d.
    DATA lv_to       TYPE d.

    " GIVEN: 89,90 TRY normal fiyatli, %10 indirimli bir kalem
    lv_from = cl_abap_context_info=>get_system_date( ).
    lv_to   = lv_from + 7.
    DATA(lv_promo) = add_promo( iv_from = lv_from iv_to = lv_to ).
    DATA(lv_item)  = add_item( iv_promo_uuid = lv_promo
                               iv_product    = 'P0001'
                               iv_price      = '89.90'
                               iv_disc       = '10.00' ).

    " WHEN: fiyat hesaplama belirlemesini cagir
    mo_cut_item->calculatepromoprice(
      EXPORTING keys     = VALUE #( ( ItemUUID  = lv_item
                                      %is_draft = if_abap_behv=>mk-off ) )
      CHANGING  reported = ls_reported ).

    " THEN: sahte tampondan kalemi oku, kampanya fiyatini kontrol et
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        FIELDS ( PromoPrice )
        WITH VALUE #( ( ItemUUID = lv_item %is_draft = if_abap_behv=>mk-off ) )
      RESULT DATA(lt_items).

    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ 1 ]-PromoPrice
      exp = '80.91'
      msg = '89.90 with 10% discount must be 80.91' ).
  ENDMETHOD.


  METHOD approve_without_items_fails.
    " Aksiyon: cevap tipleri EARLY
    DATA ls_failed   TYPE RESPONSE FOR FAILED EARLY zr_prm_promo_mk.
    DATA ls_reported TYPE RESPONSE FOR REPORTED EARLY zr_prm_promo_mk.
    DATA ls_mapped   TYPE RESPONSE FOR MAPPED EARLY zr_prm_promo_mk.
    DATA lt_result   TYPE TABLE FOR ACTION RESULT zr_prm_promo_mk\\Promotion~approve.
    DATA lv_from     TYPE d.
    DATA lv_to       TYPE d.

    " GIVEN: kalemsiz kampanya
    lv_from = cl_abap_context_info=>get_system_date( ).
    lv_to   = lv_from + 7.
    DATA(lv_uuid) = add_promo( iv_from = lv_from iv_to = lv_to ).

    " WHEN: Approve aksiyonunu dogrudan cagir
    mo_cut_promo->approve(
      EXPORTING keys     = VALUE #( ( PromoUUID = lv_uuid
                                      %is_draft = if_abap_behv=>mk-off ) )
      CHANGING  result   = lt_result
                mapped   = ls_mapped
                failed   = ls_failed
                reported = ls_reported ).

    " THEN: basarisiz olmali
    cl_abap_unit_assert=>assert_not_initial(
      act = ls_failed-promotion
      msg = 'Approve without items must fail' ).
  ENDMETHOD.


  METHOD overlap_is_detected.
    " Dogrulama: cevap tipleri LATE
    DATA ls_failed   TYPE RESPONSE FOR FAILED LATE zr_prm_promo_mk.
    DATA ls_reported TYPE RESPONSE FOR REPORTED LATE zr_prm_promo_mk.
    DATA lt_promo    TYPE STANDARD TABLE OF zprm_promo_mk WITH EMPTY KEY.
    DATA lt_item     TYPE STANDARD TABLE OF zprm_pitem_mk WITH EMPTY KEY.
    DATA lv_today    TYPE d.
    DATA lv_from     TYPE d.
    DATA lv_to       TYPE d.

    " GIVEN 1: SAHTE TABLODA P0001'i iceren yayindaki bir kampanya
    "          (bugun ... bugun+10). Cakisma kontrolu bunu SELECT ile bulacak.
    lv_today = cl_abap_context_info=>get_system_date( ).
    DATA(lv_existing) = cl_system_uuid=>create_uuid_x16_static( ).

    lt_promo = VALUE #( ( promo_uuid    = lv_existing
                          promo_id      = 'PR00000099'
                          description   = 'Existing promo'
                          promo_type    = 'P'
                          valid_from    = lv_today
                          valid_to      = lv_today + 10
                          status        = 'X'
                          currency_code = 'TRY' ) ).
    lt_item = VALUE #( ( item_uuid     = cl_system_uuid=>create_uuid_x16_static( )
                         parent_uuid   = lv_existing
                         product_id    = 'P0001'
                         regular_price = '89.90'
                         promo_price   = '71.92'
                         discount_pct  = '20.00'
                         currency_code = 'TRY' ) ).
    go_sql_env->insert_test_data( lt_promo ).
    go_sql_env->insert_test_data( lt_item ).

    " GIVEN 2: SAHTE TAMPONDA yeni kampanya, ayni urun, bugun+5 ... bugun+15
    lv_from = lv_today + 5.
    lv_to   = lv_today + 15.
    DATA(lv_promo) = add_promo( iv_from = lv_from iv_to = lv_to ).
    DATA(lv_item)  = add_item( iv_promo_uuid = lv_promo
                               iv_product    = 'P0001'
                               iv_price      = '89.90'
                               iv_disc       = '10.00' ).

    " WHEN: kalem cakisma dogrulamasini cagir
    mo_cut_item->validateitemoverlap(
      EXPORTING keys     = VALUE #( ( ItemUUID  = lv_item
                                      %is_draft = if_abap_behv=>mk-off ) )
      CHANGING  failed   = ls_failed
                reported = ls_reported ).

    " THEN: kalem basarisiz isaretlenmeli
    cl_abap_unit_assert=>assert_not_initial(
      act = ls_failed-item
      msg = 'Overlapping promotion must be detected' ).
  ENDMETHOD.

ENDCLASS.
