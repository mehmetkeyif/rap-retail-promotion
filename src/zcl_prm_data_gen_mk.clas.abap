CLASS zcl_prm_data_gen_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_prm_data_gen_mk IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lt_prod  TYPE STANDARD TABLE OF zprm_prod_mk  WITH EMPTY KEY.
    DATA lt_promo TYPE STANDARD TABLE OF zprm_promo_mk WITH EMPTY KEY.
    DATA lt_item  TYPE STANDARD TABLE OF zprm_pitem_mk WITH EMPTY KEY.
    DATA lv_ts    TYPE timestampl.

    " Eski test verisini temizle
    DELETE FROM zprm_pitem_mk.
    DELETE FROM zprm_promo_mk.
    DELETE FROM zprm_prod_mk.

    " 1) Urunler
    lt_prod = VALUE #(
      ( product_id = 'P0001' description = 'Shampoo 400 ml'          category = 'HAIR'      base_price = '89.90'  currency_code = 'TRY' )
      ( product_id = 'P0002' description = 'Hair Conditioner 350 ml' category = 'HAIR'      base_price = '99.90'  currency_code = 'TRY' )
      ( product_id = 'P0003' description = 'Hair Mask 300 ml'        category = 'HAIR'      base_price = '149.90' currency_code = 'TRY' )
      ( product_id = 'P0004' description = 'Face Cream 50 ml'        category = 'SKIN'      base_price = '249.90' currency_code = 'TRY' )
      ( product_id = 'P0005' description = 'Sunscreen SPF50 50 ml'   category = 'SKIN'      base_price = '329.90' currency_code = 'TRY' )
      ( product_id = 'P0006' description = 'Facial Cleanser 200 ml'  category = 'SKIN'      base_price = '179.90' currency_code = 'TRY' )
      ( product_id = 'P0007' description = 'Deodorant 150 ml'        category = 'BODY'      base_price = '79.90'  currency_code = 'TRY' )
      ( product_id = 'P0008' description = 'Shower Gel 500 ml'       category = 'BODY'      base_price = '69.90'  currency_code = 'TRY' )
      ( product_id = 'P0009' description = 'Toothpaste 75 ml'        category = 'ORAL'      base_price = '54.90'  currency_code = 'TRY' )
      ( product_id = 'P0010' description = 'Eau de Parfum 100 ml'    category = 'FRAGRANCE' base_price = '899.90' currency_code = 'TRY' ) ).
    INSERT zprm_prod_mk FROM TABLE @lt_prod.

    " 2) Kampanyalar ve kalemler
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_user)  = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_ts.

    TRY.
        DATA(lv_p1) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_p2) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_p3) = cl_system_uuid=>create_uuid_x16_static( ).

        lt_promo = VALUE #(
          ( promo_uuid = lv_p1 promo_id = 'PR00000001' description = 'Haircare Week - 20% off'
            promo_type = 'P' valid_from = lv_today      valid_to = lv_today + 7
            status = 'X' currency_code = 'TRY' )
          ( promo_uuid = lv_p2 promo_id = 'PR00000002' description = 'Skincare Fixed Price Days'
            promo_type = 'F' valid_from = lv_today + 10 valid_to = lv_today + 20
            status = 'N' currency_code = 'TRY' )
          ( promo_uuid = lv_p3 promo_id = 'PR00000003' description = 'Summer Body Care - 30% off'
            promo_type = 'P' valid_from = lv_today - 60 valid_to = lv_today - 30
            status = 'E' currency_code = 'TRY' ) ).

        LOOP AT lt_promo ASSIGNING FIELD-SYMBOL(<ls_promo>).
          <ls_promo>-local_created_by      = lv_user.
          <ls_promo>-local_created_at      = lv_ts.
          <ls_promo>-local_last_changed_by = lv_user.
          <ls_promo>-local_last_changed_at = lv_ts.
          <ls_promo>-last_changed_at       = lv_ts.
        ENDLOOP.

        lt_item = VALUE #(
          " PR00000001 - %20 indirim
          ( item_uuid = cl_system_uuid=>create_uuid_x16_static( ) parent_uuid = lv_p1
            product_id = 'P0001' regular_price = '89.90'  promo_price = '71.92'  discount_pct = '20.00' currency_code = 'TRY' )
          ( item_uuid = cl_system_uuid=>create_uuid_x16_static( ) parent_uuid = lv_p1
            product_id = 'P0002' regular_price = '99.90'  promo_price = '79.92'  discount_pct = '20.00' currency_code = 'TRY' )
          ( item_uuid = cl_system_uuid=>create_uuid_x16_static( ) parent_uuid = lv_p1
            product_id = 'P0003' regular_price = '149.90' promo_price = '119.92' discount_pct = '20.00' currency_code = 'TRY' )
          " PR00000002 - sabit fiyat
          ( item_uuid = cl_system_uuid=>create_uuid_x16_static( ) parent_uuid = lv_p2
            product_id = 'P0004' regular_price = '249.90' promo_price = '199.90' discount_pct = '20.01' currency_code = 'TRY' )
          ( item_uuid = cl_system_uuid=>create_uuid_x16_static( ) parent_uuid = lv_p2
            product_id = 'P0005' regular_price = '329.90' promo_price = '279.90' discount_pct = '15.16' currency_code = 'TRY' )
          " PR00000003 - bitmis kampanya
          ( item_uuid = cl_system_uuid=>create_uuid_x16_static( ) parent_uuid = lv_p3
            product_id = 'P0008' regular_price = '69.90'  promo_price = '48.93'  discount_pct = '30.00' currency_code = 'TRY' ) ).

        LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
          <ls_item>-local_last_changed_at = lv_ts.
        ENDLOOP.

      CATCH cx_uuid_error INTO DATA(lx_uuid).
        out->write( |UUID hatasi: { lx_uuid->get_text( ) }| ).
        RETURN.
    ENDTRY.

    INSERT zprm_promo_mk FROM TABLE @lt_promo.
    INSERT zprm_pitem_mk FROM TABLE @lt_item.

    out->write( |{ lines( lt_prod ) } urun, { lines( lt_promo ) } kampanya, { lines( lt_item ) } kalem yazildi.| ).
  ENDMETHOD.
ENDCLASS.
