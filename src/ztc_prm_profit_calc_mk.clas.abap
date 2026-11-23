"! <p>Birim testleri: kârlılık motoru, stratejiler ve factory</p>
"! Veritabanı kullanılmaz: calculate_item saf iş mantığıdır.
"!@testing ZCL_PRM_PROFIT_CALC_MK
CLASS ztc_prm_profit_calc_mk DEFINITION
  PUBLIC FINAL
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    " Test edilen nesne (CUT = Class Under Test)
    DATA mo_cut TYPE REF TO zcl_prm_profit_calc_mk.

    METHODS setup.

    " ---- Stratejiler ----
    METHODS pct_strategy_price        FOR TESTING.
    METHODS bxgy_strategy_price       FOR TESTING.
    METHODS fix_strategy_price        FOR TESTING.
    " ---- Factory ----
    METHODS factory_returns_strategy  FOR TESTING.
    " ---- Hesap motoru ve sınır değerleri ----
    METHODS loss_is_detected          FOR TESTING.
    METHODS ten_percent_is_ok         FOR TESTING.
    METHODS below_ten_percent_is_low  FOR TESTING.
    METHODS zero_price_is_low         FOR TESTING.
ENDCLASS.



CLASS ztc_prm_profit_calc_mk IMPLEMENTATION.

  METHOD setup.
    " Her testten önce yeni bir motor nesnesi: testler birbirini etkilemez
    mo_cut = NEW #( ).
  ENDMETHOD.


  METHOD pct_strategy_price.
    " 89,90 × (100 − 20) / 100 = 71,92
    DATA(lo_strategy) = NEW zcl_prm_strategy_pct_mk( ).
    DATA(lv_price) = lo_strategy->zif_prm_price_strategy_mk~get_effective_price(
                       VALUE #( regular_price = '89.90' discount_pct = '20.00' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_price exp = '71.92' ).
  ENDMETHOD.


  METHOD bxgy_strategy_price.
    " Varsayılan 3 al 2 öde: 54,90 × 2 / 3 = 36,60
    DATA(lo_3for2) = NEW zcl_prm_strategy_bxgy_mk( ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_3for2->zif_prm_price_strategy_mk~get_effective_price( VALUE #( regular_price = '54.90' ) )
      exp = '36.60' ).

    " Parametreli 4 al 3 öde: 100,00 × 3 / 4 = 75,00 (constructor çalışıyor mu?)
    DATA(lo_4for3) = NEW zcl_prm_strategy_bxgy_mk( iv_buy = 4 iv_pay = 3 ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_4for3->zif_prm_price_strategy_mk~get_effective_price( VALUE #( regular_price = '100.00' ) )
      exp = '75.00' ).
  ENDMETHOD.


  METHOD fix_strategy_price.
    " Sabit fiyat: kayıtlı kampanya fiyatı aynen döner, yüzde dikkate alınmaz
    DATA(lo_strategy) = NEW zcl_prm_strategy_fix_mk( ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_strategy->zif_prm_price_strategy_mk~get_effective_price(
              VALUE #( regular_price = '249.90' promo_price = '199.90' discount_pct = '50.00' ) )
      exp = '199.90' ).
  ENDMETHOD.


  METHOD factory_returns_strategy.
    " IS INSTANCE OF: referansın arkasındaki nesne hangi sınıftan?
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_prm_strategy_factory_mk=>get_strategy( 'P' ) IS INSTANCE OF zcl_prm_strategy_pct_mk )
      msg = 'P için yüzde stratejisi beklenir' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_prm_strategy_factory_mk=>get_strategy( 'B' ) IS INSTANCE OF zcl_prm_strategy_bxgy_mk )
      msg = 'B için X al Y öde stratejisi beklenir' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_prm_strategy_factory_mk=>get_strategy( 'F' ) IS INSTANCE OF zcl_prm_strategy_fix_mk )
      msg = 'F için sabit fiyat stratejisi beklenir' ).
    " Tanımsız tip -> güvenli varsayılan: sabit fiyat
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( zcl_prm_strategy_factory_mk=>get_strategy( 'X' ) IS INSTANCE OF zcl_prm_strategy_fix_mk )
      msg = 'Tanımsız tip için sabit fiyat beklenir' ).
  ENDMETHOD.


  METHOD loss_is_detected.
    " P0003: 149,90 %20 -> 119,92; maliyet 127,42 -> marj -7,50 (%-6,25) -> LOSS
    DATA(ls_calc) = mo_cut->calculate_item(
                      is_item = VALUE #( promo_type = 'P' regular_price = '149.90' discount_pct = '20.00' )
                      iv_cost = '127.42' ).
    cl_abap_unit_assert=>assert_equals( act = ls_calc-unit_margin   exp = '-7.50' ).
    cl_abap_unit_assert=>assert_equals( act = ls_calc-margin_pct    exp = '-6.25' ).
    cl_abap_unit_assert=>assert_equals( act = ls_calc-profit_status exp = 'LOSS' ).
  ENDMETHOD.


  METHOD ten_percent_is_ok.
    " SINIR DEĞERİ: P0009, 3 al 2 öde -> 36,60; maliyet 32,94 -> marj 3,66 = TAM %10
    " Kural "< %10 ise LOW" olduğu için tam %10 -> OK
    DATA(ls_calc) = mo_cut->calculate_item(
                      is_item = VALUE #( promo_type = 'B' regular_price = '54.90' )
                      iv_cost = '32.94' ).
    cl_abap_unit_assert=>assert_equals( act = ls_calc-margin_pct    exp = '10.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_calc-profit_status exp = 'OK' ).
  ENDMETHOD.


  METHOD below_ten_percent_is_low.
    " Sabit fiyat 100,00; maliyet 91,00 -> marj 9,00 = %9 -> LOW
    DATA(ls_calc) = mo_cut->calculate_item(
                      is_item = VALUE #( promo_type = 'F' promo_price = '100.00' )
                      iv_cost = '91.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_calc-profit_status exp = 'LOW' ).
  ENDMETHOD.


  METHOD zero_price_is_low.
    " Fiyat 0: sıfıra bölme olmamalı (dump yok), yüzde 0, durum LOW
    DATA(ls_calc) = mo_cut->calculate_item(
                      is_item = VALUE #( promo_type = 'F' promo_price = 0 )
                      iv_cost = 0 ).
    cl_abap_unit_assert=>assert_equals( act = ls_calc-margin_pct    exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = ls_calc-profit_status exp = 'LOW' ).
  ENDMETHOD.

ENDCLASS.
