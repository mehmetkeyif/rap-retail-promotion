" ======================================================================
" DAVRANIS ISLEYICI SINIFLARI
" Ortak kavramlar:
"  keys          : Kuralin calisacagi kayitlarin anahtarlari (RAP verir)
"  %tky          : Anahtar + taslak mi/asil mi bilgisi
"  IN LOCAL MODE : Yetki ve readonly kontrollerini atla (kendi icimizden)
"  failed        : "Bu kayitta islem basarisiz" listesi
"  reported      : Kullaniciya gosterilecek mesajlar
" ======================================================================

" ----------------------------------------------------------------------
" 1) KAMPANYA BASLIGI ISLEYICISI
" ----------------------------------------------------------------------
CLASS lhc_Promotion DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Genel yetki: "Bu kullanici bu islemi yapabilir mi?"
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Promotion
      RESULT result.

    " YENI - Ozellik kontrolu: "Bu kayitta bu buton acik mi kapali mi?"
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Promotion
      RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Promotion~setDefaults.

    METHODS setPromoID FOR DETERMINE ON SAVE
      IMPORTING keys FOR Promotion~setPromoID.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateDates.

    " YENI - Aksiyonlar. RESULT result : Aksiyon sonrasi guncel kayit
    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION Promotion~approve RESULT result.

    METHODS publish FOR MODIFY
      IMPORTING keys FOR ACTION Promotion~publish RESULT result.

ENDCLASS.

CLASS lhc_Promotion IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Deneme projesi: herkese her isleme izin ver.
    " DIKKAT: Yeni aksiyonlari buraya eklemezsek, dunku Edit butonu gibi
    " Approve ve Publish butonlari da pasif kalir.
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
    " YENI
    IF requested_authorizations-%action-approve = if_abap_behv=>mk-on.
      result-%action-approve = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%action-publish = if_abap_behv=>mk-on.
      result-%action-publish = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    " Fiori her kampanyayi gosterirken bu metodu cagirir ve butonlari
    " buradan gelen cevaba gore acar/kapatir.
    "
    " Yetki ile farki: Yetki "KIM yapabilir?" sorusunu, ozellik kontrolu
    " "Bu KAYITTA su an yapilabilir mi?" sorusunu cevaplar.

    " 1) Kampanyalarin durumunu oku.
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    " 2) Her kampanya icin karar ver.
    "    fc-o-enabled  : islem/buton acik
    "    fc-o-disabled : islem/buton kapali (pasif)
    "    COND #( WHEN ... THEN ... ELSE ... ) : kosula gore deger sec
    result = VALUE #( FOR promo IN promos
      LET locked = xsdbool( promo-Status = 'X' OR promo-Status = 'E' )
      IN
      ( %tky = promo-%tky

        " Yayinda veya bitmis kampanya degistirilemez/silinemez,
        " Edit acilamaz, kalem eklenemez.
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

        " Approve yalnizca Yeni (N) kampanyada
        %action-approve = COND #( WHEN promo-Status = 'N'
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled )

        " Publish yalnizca Onayli (A) kampanyada
        %action-publish = COND #( WHEN promo-Status = 'A'
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ) ) ).
    " LET locked = ... IN : Her satir icin bir kez hesaplanan yardimci
    " degisken. Ayni kosulu dort kez yazmamak icin.
    " xsdbool( ... ) : Kosulu dogru/yanlis (abap_true/abap_false) degerine cevirir.
  ENDMETHOD.


  METHOD setDefaults.
    " Yeni kampanyaya durum N ve para birimi TRY ver (dunku kod)
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
    " Kaydederken otomatik kampanya numarasi ver (dunku kod)
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
    " Tarih kontrolu (dunku kod)
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


  METHOD approve.
    " YENI - Kampanyayi onayla: N -> A
    " Kural: En az bir kalemi olmayan kampanya onaylanamaz.
    DATA lt_ok TYPE TABLE FOR UPDATE zr_prm_promo_mk\\Promotion.

    " 1) Kampanyalari VE kalemlerini tek komutta oku.
    "    BY \_Item : Kampanyadan kalemlerine gecis (association ile okuma)
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

      " 2) Bu kampanyaya ait kalem var mi?
      "    line_exists( ... ) : Tabloda bu kosula uyan satir var mi?
      "    %is_draft'i de karsilastiriyoruz: taslak kampanyanin taslak
      "    kalemleri, asil kampanyanin asil kalemleri sayilmali.
      IF NOT line_exists( items[ ParentUUID = promo-PromoUUID
                                 %is_draft  = promo-%is_draft ] ).
        " Kalem yok: islemi reddet ve kullaniciya soyle.
        APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
        APPEND VALUE #( %tky = promo-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |{ promo-PromoID }: add at least one item before approving| ) )
          TO reported-promotion.
        CONTINUE.   " Bu kampanyayi atla, siradakine gec
      ENDIF.

      " 3) Kurala uyuyor: onaylanacaklar listesine ekle ve basari mesaji ver.
      APPEND VALUE #( %tky = promo-%tky Status = 'A' ) TO lt_ok.
      APPEND VALUE #( %tky = promo-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |{ promo-PromoID } approved| ) )
        TO reported-promotion.
    ENDLOOP.

    " 4) Durumlari guncelle (Status readonly; IN LOCAL MODE sayesinde yazabiliyoruz)
    IF lt_ok IS NOT INITIAL.
      MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
        ENTITY Promotion
          UPDATE FIELDS ( Status )
          WITH lt_ok.
    ENDIF.

    " 5) Guncel kayitlari Fiori'ye geri dondur (result [1] $self).
    "    ALL FIELDS : tum alanlari oku
    "    %param     : aksiyonun dondurdugu veri
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
    " YENI - Kampanyayi yayinla (magazalara/POS'a gonder): A -> X
    " Kural: Bitis tarihi gecmis kampanya yayinlanamaz.
    DATA lt_ok TYPE TABLE FOR UPDATE zr_prm_promo_mk\\Promotion.

    " Bugunun tarihi (ABAP Cloud'da sy-datum yerine onerilen yol)
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

      " Gercek projede burada kampanya POS sistemlerine gonderilir
      " (ornegin bir is olayi / business event yayinlanarak).
      " Bunu 8. haftada Web API ile ele alacagiz.
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


" ----------------------------------------------------------------------
" 2) KAMPANYA KALEMI ISLEYICISI (dunku kodun aynisi)
" ----------------------------------------------------------------------
CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS fillFromProduct FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~fillFromProduct.
    METHODS calculatePromoPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculatePromoPrice.
    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateItem.
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

ENDCLASS.
