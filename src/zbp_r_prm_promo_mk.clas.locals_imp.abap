" ======================================================================
" Test sinifinin on bildirimi. Asil tanimi Test Classes sekmesinde.
" Asagidaki isleyici siniflar bu test sinifina "FRIENDS" ile ozel
" metotlarina erisim izni veriyor.
" ======================================================================
CLASS ltc_behavior DEFINITION DEFERRED FOR TESTING.


" ======================================================================
" 0) YARDIMCI SINIF: Cakisma kontrolu
" Hem baslik hem kalem dogrulamasi ayni mantigi kullanir.
" Girdi : kontrol edilecek kalemler + bu kalemlerin kampanyalari
" Cikti : cakisan kalemlerin listesi (kacinci kalem, hangi kampanyayla)
" ======================================================================
CLASS lcl_overlap DEFINITION.
  PUBLIC SECTION.
    " RAP'in turetilmis tiplerine ad veriyoruz (imzada dogrudan yazilamiyor)
    TYPES tt_items  TYPE TABLE FOR READ RESULT zr_prm_promo_mk\\Item.
    TYPES tt_promos TYPE TABLE FOR READ RESULT zr_prm_promo_mk\\Promotion.

    TYPES: BEGIN OF ty_conflict,
             item_index  TYPE i,
             other_promo TYPE zprm_promo_mk-promo_id,
           END OF ty_conflict,
           tt_conflict TYPE STANDARD TABLE OF ty_conflict WITH EMPTY KEY.

    CLASS-METHODS find
      IMPORTING it_items            TYPE tt_items
                it_promos           TYPE tt_promos
      RETURNING VALUE(rt_conflicts) TYPE tt_conflict.
ENDCLASS.

CLASS lcl_overlap IMPLEMENTATION.
  METHOD find.
    LOOP AT it_items INTO DATA(item).
      DATA(lv_index) = sy-tabix.

      IF item-ProductID IS INITIAL.
        CONTINUE.
      ENDIF.

      " Kalemin kampanyasini (tarihleri icin) bul
      READ TABLE it_promos INTO DATA(promo)
        WITH KEY PromoUUID = item-ParentUUID
                 %is_draft = item-%is_draft.
      IF sy-subrc <> 0 OR promo-ValidFrom IS INITIAL OR promo-ValidTo IS INITIAL.
        CONTINUE.
      ENDIF.

      " Ayni urunu iceren, tarihi cakisan BASKA bir (bitmemis) kampanya var mi?
      " Cakisma: diger.baslangic <= bizim.bitis VE diger.bitis >= bizim.baslangic
      SELECT SINGLE FROM zprm_pitem_mk AS i
        INNER JOIN zprm_promo_mk AS h
          ON h~promo_uuid = i~parent_uuid
        FIELDS h~promo_id
        WHERE i~product_id  =  @item-ProductID
          AND h~promo_uuid  <> @item-ParentUUID
          AND h~status      <> 'E'
          AND h~valid_from  <= @promo-ValidTo
          AND h~valid_to    >= @promo-ValidFrom
        INTO @DATA(lv_other_promo).

      IF sy-subrc = 0.
        APPEND VALUE #( item_index  = lv_index
                        other_promo = lv_other_promo ) TO rt_conflicts.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


" ======================================================================
" 1) KAMPANYA BASLIGI ISLEYICISI
" FRIENDS ltc_behavior : Test sinifi bu sinifin ozel metotlarini
"                        cagirabilsin.
" ======================================================================
CLASS lhc_Promotion DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltc_behavior.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Promotion
      RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Promotion
      RESULT result.
    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Promotion~setDefaults.
    METHODS setPromoID FOR DETERMINE ON SAVE
      IMPORTING keys FOR Promotion~setPromoID.
    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateDates.
    METHODS validateOverlap FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateOverlap.
    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION Promotion~approve RESULT result.
    METHODS publish FOR MODIFY
      IMPORTING keys FOR ACTION Promotion~publish RESULT result.
ENDCLASS.

CLASS lhc_Promotion IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Herkese her isleme izin (deneme projesi)
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      result-%action-Edit = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-approve = if_abap_behv=>mk-on.
      result-%action-approve = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-publish = if_abap_behv=>mk-on.
      result-%action-publish = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    " Duruma gore butonlari ac/kapat
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    result = VALUE #( FOR promo IN promos
      LET locked = xsdbool( promo-Status = 'X' OR promo-Status = 'E' )
      IN
      ( %tky = promo-%tky
        %update      = COND #( WHEN locked = abap_true
                               THEN if_abap_behv=>fc-o-disabled
                               ELSE if_abap_behv=>fc-o-enabled )
        %delete      = COND #( WHEN locked = abap_true
                               THEN if_abap_behv=>fc-o-disabled
                               ELSE if_abap_behv=>fc-o-enabled )
        %action-Edit = COND #( WHEN locked = abap_true
                               THEN if_abap_behv=>fc-o-disabled
                               ELSE if_abap_behv=>fc-o-enabled )
        %assoc-_Item = COND #( WHEN locked = abap_true
                               THEN if_abap_behv=>fc-o-disabled
                               ELSE if_abap_behv=>fc-o-enabled )
        %action-approve = COND #( WHEN promo-Status = 'N'
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled )
        %action-publish = COND #( WHEN promo-Status = 'A'
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.


  METHOD setDefaults.
    " Yeni kampanya: durum N, para birimi TRY
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( Status CurrencyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    DELETE promos WHERE Status IS NOT INITIAL.
    IF promos IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        UPDATE FIELDS ( Status CurrencyCode )
        WITH VALUE #( FOR promo IN promos
                      ( %tky         = promo-%tky
                        Status       = 'N'
                        CurrencyCode = COND #( WHEN promo-CurrencyCode IS INITIAL
                                               THEN 'TRY'
                                               ELSE promo-CurrencyCode ) ) ).
  ENDMETHOD.


  METHOD setPromoID.
    " Kaydederken otomatik numara: PR00000001, PR00000002 ...
    DATA lv_last   TYPE i.
    DATA lv_numc   TYPE n LENGTH 8.
    DATA lt_update TYPE TABLE FOR UPDATE zr_prm_promo_mk\\Promotion.

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( PromoID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    DELETE promos WHERE PromoID IS NOT INITIAL.
    IF promos IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE FROM zprm_promo_mk
      FIELDS MAX( promo_id )
      INTO @DATA(lv_max_id).

    IF lv_max_id IS NOT INITIAL.
      lv_last = substring( val = lv_max_id off = 2 len = 8 ).
    ENDIF.

    LOOP AT promos INTO DATA(promo).
      lv_last = lv_last + 1.
      lv_numc = lv_last.
      APPEND VALUE #( %tky    = promo-%tky
                      PromoID = |PR{ lv_numc }| ) TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        UPDATE FIELDS ( PromoID )
        WITH lt_update.
  ENDMETHOD.


  METHOD validateDates.
    " Tarihler dolu olmali, bitis >= baslangic
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( ValidFrom ValidTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    LOOP AT promos INTO DATA(promo).
      APPEND VALUE #( %tky        = promo-%tky
                      %state_area = 'VALIDATE_DATES' ) TO reported-promotion.

      IF promo-ValidFrom IS INITIAL OR promo-ValidTo IS INITIAL.
        APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
        APPEND VALUE #( %tky        = promo-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Start date and end date are required' )
                        %element-ValidFrom = if_abap_behv=>mk-on
                        %element-ValidTo   = if_abap_behv=>mk-on )
          TO reported-promotion.
      ELSEIF promo-ValidTo < promo-ValidFrom.
        APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
        APPEND VALUE #( %tky        = promo-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'End date cannot be before start date' )
                        %element-ValidTo = if_abap_behv=>mk-on )
          TO reported-promotion.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validateOverlap.
    " Tarih degisince kampanyanin TUM kalemleri icin cakisma kontrolu
    DATA lt_items TYPE lcl_overlap=>tt_items.

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( PromoID ValidFrom ValidTo )
        WITH CORRESPONDING #( keys )
        RESULT DATA(promos)
      ENTITY Promotion BY \_Item
        FIELDS ( ProductID ParentUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(items_by_promo).

    lt_items = CORRESPONDING #( items_by_promo ).

    DATA(conflicts) = lcl_overlap=>find( it_items  = lt_items
                                         it_promos = promos ).

    LOOP AT promos INTO DATA(promo).
      APPEND VALUE #( %tky        = promo-%tky
                      %state_area = 'VALIDATE_OVERLAP' ) TO reported-promotion.
    ENDLOOP.

    LOOP AT conflicts INTO DATA(conflict).
      DATA(item)       = lt_items[ conflict-item_index ].
      DATA(item_promo) = promos[ PromoUUID = item-ParentUUID
                                 %is_draft = item-%is_draft ].

      APPEND VALUE #( %tky = item_promo-%tky ) TO failed-promotion.
      APPEND VALUE #( %tky        = item_promo-%tky
                      %state_area = 'VALIDATE_OVERLAP'
                      %msg        = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = |Product { item-ProductID } is already in { conflict-other_promo } for overlapping dates| )
                      %element-ValidFrom = if_abap_behv=>mk-on
                      %element-ValidTo   = if_abap_behv=>mk-on )
        TO reported-promotion.
    ENDLOOP.
  ENDMETHOD.


  METHOD approve.
    " N -> A. Kalemsiz kampanya onaylanamaz.
    DATA lt_ok TYPE TABLE FOR UPDATE zr_prm_promo_mk\\Promotion.

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( PromoID Status )
        WITH CORRESPONDING #( keys )
        RESULT DATA(promos)
      ENTITY Promotion BY \_Item
        FIELDS ( ParentUUID )
        WITH CORRESPONDING #( keys )
        RESULT DATA(items).

    LOOP AT promos INTO DATA(promo).
      IF NOT line_exists( items[ ParentUUID = promo-PromoUUID
                                 %is_draft  = promo-%is_draft ] ).
        APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
        APPEND VALUE #( %tky = promo-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |{ promo-PromoID }: add at least one item before approving| ) )
          TO reported-promotion.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = promo-%tky Status = 'A' ) TO lt_ok.
      APPEND VALUE #( %tky = promo-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |{ promo-PromoID } approved| ) )
        TO reported-promotion.
    ENDLOOP.

    IF lt_ok IS NOT INITIAL.
      MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
        ENTITY Promotion
          UPDATE FIELDS ( Status )
          WITH lt_ok.
    ENDIF.

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(updated).

    result = VALUE #( FOR upd IN updated
                      ( %tky   = upd-%tky
                        %param = upd ) ).
  ENDMETHOD.


  METHOD publish.
    " A -> X. Bitis tarihi gecmis kampanya yayinlanamaz.
    DATA lt_ok TYPE TABLE FOR UPDATE zr_prm_promo_mk\\Promotion.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( PromoID Status ValidTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    LOOP AT promos INTO DATA(promo).
      IF promo-ValidTo < lv_today.
        APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
        APPEND VALUE #( %tky = promo-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |{ promo-PromoID }: end date is in the past, cannot publish| ) )
          TO reported-promotion.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = promo-%tky Status = 'X' ) TO lt_ok.
      APPEND VALUE #( %tky = promo-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |{ promo-PromoID } published to stores| ) )
        TO reported-promotion.
    ENDLOOP.

    IF lt_ok IS NOT INITIAL.
      MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
        ENTITY Promotion
          UPDATE FIELDS ( Status )
          WITH lt_ok.
    ENDIF.

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(updated).

    result = VALUE #( FOR upd IN updated
                      ( %tky   = upd-%tky
                        %param = upd ) ).
  ENDMETHOD.

ENDCLASS.


" ======================================================================
" 2) KAMPANYA KALEMI ISLEYICISI
" ======================================================================
CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltc_behavior.
  PRIVATE SECTION.
    METHODS fillFromProduct FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~fillFromProduct.
    METHODS calculatePromoPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculatePromoPrice.
    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateItem.
    METHODS validateItemOverlap FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateItemOverlap.
ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

  METHOD fillFromProduct.
    " Urun secilince normal fiyat ve para birimini getir
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        FIELDS ( ProductID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DELETE items WHERE ProductID IS INITIAL.
    IF items IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM zi_prm_product_mk
      FIELDS ProductID, BasePrice, CurrencyCode
      FOR ALL ENTRIES IN @items
      WHERE ProductID = @items-ProductID
      INTO TABLE @DATA(products).

    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( RegularPrice CurrencyCode )
        WITH VALUE #( FOR item IN items
                      ( %tky         = item-%tky
                        RegularPrice = VALUE #( products[ ProductID = item-ProductID ]-BasePrice OPTIONAL )
                        CurrencyCode = VALUE #( products[ ProductID = item-ProductID ]-CurrencyCode OPTIONAL ) ) ).
  ENDMETHOD.


  METHOD calculatePromoPrice.
    " Kampanya fiyati = Normal fiyat x (100 - indirim) / 100
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        FIELDS ( RegularPrice DiscountPct )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( PromoPrice )
        WITH VALUE #( FOR item IN items
                      ( %tky       = item-%tky
                        PromoPrice = item-RegularPrice * ( 100 - item-DiscountPct ) / 100 ) ).
  ENDMETHOD.


  METHOD validateItem.
    " Urun var mi, indirim %0-%100 arasinda mi
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        FIELDS ( ProductID RegularPrice DiscountPct )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item BY \_Promo
        FROM CORRESPONDING #( items )
      LINK DATA(item_promo_links).

    LOOP AT items INTO DATA(item).
      DATA(promo_tky) = item_promo_links[ KEY id source-%tky = item-%tky ]-target-%tky.

      APPEND VALUE #( %tky        = item-%tky
                      %state_area = 'VALIDATE_ITEM' ) TO reported-item.

      IF item-RegularPrice IS INITIAL.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky        = item-%tky
                        %state_area = 'VALIDATE_ITEM'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = |Product { item-ProductID } not found| )
                        %path       = VALUE #( promotion-%tky = promo_tky )
                        %element-ProductID = if_abap_behv=>mk-on )
          TO reported-item.
      ENDIF.

      IF item-DiscountPct <= 0 OR item-DiscountPct >= 100.
        APPEND VALUE #( %tky = item-%tky ) TO failed-item.
        APPEND VALUE #( %tky        = item-%tky
                        %state_area = 'VALIDATE_ITEM'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Discount must be between 0 and 100 percent' )
                        %path       = VALUE #( promotion-%tky = promo_tky )
                        %element-DiscountPct = if_abap_behv=>mk-on )
          TO reported-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validateItemOverlap.
    " Urun eklenince/degisince cakisma kontrolu
    DATA lt_promos TYPE lcl_overlap=>tt_promos.

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        FIELDS ( ProductID ParentUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item BY \_Promo
        FIELDS ( ValidFrom ValidTo )
        WITH CORRESPONDING #( items )
        RESULT DATA(promos_by_item)
        LINK DATA(item_promo_links).

    lt_promos = CORRESPONDING #( promos_by_item ).

    DATA(conflicts) = lcl_overlap=>find( it_items  = items
                                         it_promos = lt_promos ).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky        = item-%tky
                      %state_area = 'VALIDATE_OVERLAP' ) TO reported-item.
    ENDLOOP.

    LOOP AT conflicts INTO DATA(conflict).
      DATA(conflict_item) = items[ conflict-item_index ].
      DATA(promo_tky) = item_promo_links[ KEY id source-%tky = conflict_item-%tky ]-target-%tky.

      APPEND VALUE #( %tky = conflict_item-%tky ) TO failed-item.
      APPEND VALUE #( %tky        = conflict_item-%tky
                      %state_area = 'VALIDATE_OVERLAP'
                      %msg        = new_message_with_text(
                                      severity = if_abap_behv_message=>severity-error
                                      text     = |Product { conflict_item-ProductID } is already in { conflict-other_promo } for overlapping dates| )
                      %path       = VALUE #( promotion-%tky = promo_tky )
                      %element-ProductID = if_abap_behv=>mk-on )
        TO reported-item.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
