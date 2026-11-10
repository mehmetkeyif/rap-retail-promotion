" ======================================================================
" DAVRANIS ISLEYICI SINIFLARI
" Davranis tanimindaki her kural (determination, validation) icin burada
" bir metot var. RAP bu metotlari dogru anda kendisi cagirir.
"
" Ortak kavramlar:
"  keys         : Kuralin calisacagi kayitlarin anahtarlari (RAP verir)
"  %tky         : "Transactional key" = anahtar + taslak mi/asil mi bilgisi.
"                 Taslakli senaryoda kayitlari her zaman %tky ile tasiriz.
"  IN LOCAL MODE: Yetki ve readonly kontrollerini atla. Kendi is
"                 nesnemizin icinden readonly alanlari (PromoID, fiyatlar)
"                 ancak bu modda degistirebiliriz.
"  EML          : READ ENTITIES / MODIFY ENTITIES komutlari. Veritabani
"                 tablosuna dogrudan degil, is nesnesi uzerinden erisim.
"                 Taslaklar da dahil, RAP dogru yere okur/yazar.
" ======================================================================

" ----------------------------------------------------------------------
" 1) KAMPANYA BASLIGI ISLEYICISI
" ----------------------------------------------------------------------
CLASS lhc_Promotion DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Genel yetki (dun yazdigimiz)
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Promotion
      RESULT result.

    " Belirleme: varsayilan degerler (durum N, para birimi TRY)
    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Promotion~setDefaults.

    " Belirleme: otomatik kampanya numarasi
    METHODS setPromoID FOR DETERMINE ON SAVE
      IMPORTING keys FOR Promotion~setPromoID.

    " Dogrulama: tarih kontrolu
    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateDates.

ENDCLASS.

CLASS lhc_Promotion IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Deneme projesi: herkese her isleme izin ver.
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
  ENDMETHOD.


  METHOD setDefaults.
    " 1) Yeni olusturulan kampanyalarin mevcut durum ve para birimini oku.
    "    WITH CORRESPONDING #( keys ) : keys tablosunu READ'in bekledigi
    "    yapiya cevir.
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( Status CurrencyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    " 2) Durumu zaten dolu olanlari listeden cikar (tekrar ezmeyelim).
    DELETE promos WHERE Status IS NOT INITIAL.
    IF promos IS INITIAL.
      RETURN.
    ENDIF.

    " 3) Kalanlara varsayilan degerleri yaz.
    "    FOR promo IN promos : Her kayit icin bir satir uret (dongu ifadesi)
    "    UPDATE FIELDS ( ... ) : Yalnizca bu alanlari degistir.
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
    DATA lv_last   TYPE i.             " Son kullanilan numara (sayi olarak)
    DATA lv_numc   TYPE n LENGTH 8.    " 8 haneli, basi sifirli numara
    DATA lt_update TYPE TABLE FOR UPDATE zr_prm_promo_mk\\Promotion.

    " 1) Kaydedilen kampanyalarin PromoID'sini oku.
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( PromoID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    " 2) Numarasi zaten olanlari atla.
    DELETE promos WHERE PromoID IS NOT INITIAL.
    IF promos IS INITIAL.
      RETURN.
    ENDIF.

    " 3) Veritabanindaki en buyuk numarayi bul (ornek: PR00000003).
    SELECT SINGLE FROM zprm_promo_mk
      FIELDS MAX( promo_id )
      INTO @DATA(lv_max_id).

    " 4) 'PR' onekinden sonraki 8 haneyi sayiya cevir.
    "    Hic kampanya yoksa 0'dan basla.
    IF lv_max_id IS NOT INITIAL.
      lv_last = substring( val = lv_max_id off = 2 len = 8 ).
    ENDIF.

    " 5) Her yeni kampanyaya sirayla bir sonraki numarayi ver.
    LOOP AT promos INTO DATA(promo).
      lv_last = lv_last + 1.
      lv_numc = lv_last.              " 4 -> '00000004'
      APPEND VALUE #( %tky    = promo-%tky
                      PromoID = |PR{ lv_numc }| ) TO lt_update.
    ENDLOOP.

    " 6) Numaralari yaz.
    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        UPDATE FIELDS ( PromoID )
        WITH lt_update.

    " Not: Iki kullanici ayni anda kaydederse ayni numarayi alabilir.
    " Gercek projede bunun yerine numara araligi nesnesi
    " (cl_numberrange_runtime) kullanilir. Ogrenme amacli basit tuttuk.
  ENDMETHOD.


  METHOD validateDates.
    " 1) Kontrol edilecek kampanyalarin tarihlerini oku.
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( ValidFrom ValidTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    LOOP AT promos INTO DATA(promo).

      " 2) Bu dogrulamanin onceki mesajlarini temizle.
      "    %state_area : Mesajlarin "grubu". Ayni gruba bos bir satir
      "    eklemek, taslakta daha once cikan eski hatayi siler. Boylece
      "    kullanici hatayi duzeltince mesaj ekrandan kalkar.
      APPEND VALUE #( %tky        = promo-%tky
                      %state_area = 'VALIDATE_DATES' ) TO reported-promotion.

      IF promo-ValidFrom IS INITIAL OR promo-ValidTo IS INITIAL.
        " 3a) Tarihlerden biri bos.
        "     failed   : RAP'a "bu kayit kaydedilemez" der.
        "     reported : Kullaniciya gosterilecek mesaj.
        "     %element : Mesaj hangi alanlarin yaninda gosterilsin.
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
        " 3b) Bitis tarihi baslangictan once.
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

ENDCLASS.


" ----------------------------------------------------------------------
" 2) KAMPANYA KALEMI ISLEYICISI
" ----------------------------------------------------------------------
CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Belirleme: urunden normal fiyat ve para birimini getir
    METHODS fillFromProduct FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~fillFromProduct.

    " Belirleme: kampanya fiyatini hesapla
    METHODS calculatePromoPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculatePromoPrice.

    " Dogrulama: urun var mi, indirim mantikli mi
    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~validateItem.

ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

  METHOD fillFromProduct.
    " 1) Degisen kalemlerin urun kodunu oku.
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        FIELDS ( ProductID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " Urun kodu bos olanlarla ugrasma.
    DELETE items WHERE ProductID IS INITIAL.
    IF items IS INITIAL.
      RETURN.
    ENDIF.

    " 2) Bu urunlerin fiyatlarini urun gorunumunden tek seferde oku.
    "    FOR ALL ENTRIES IN @items : items tablosundaki her urun kodu icin.
    "    Tabloya degil CDS gorunumune (ZI_) erisiyoruz; ABAP Cloud'da
    "    onerilen yol budur.
    SELECT FROM zi_prm_product_mk
      FIELDS ProductID, BasePrice, CurrencyCode
      FOR ALL ENTRIES IN @items
      WHERE ProductID = @items-ProductID
      INTO TABLE @DATA(products).

    " 3) Her kaleme kendi urununun fiyatini yaz.
    "    products[ ProductID = ... ] : Tablodan anahtara gore satir oku.
    "    OPTIONAL : Urun bulunamazsa hata verme, bos deger kullan.
    "    (Bulunamayan urunu validateItem yakalayacak.)
    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( RegularPrice CurrencyCode )
        WITH VALUE #( FOR item IN items
                      ( %tky         = item-%tky
                        RegularPrice = VALUE #( products[ ProductID = item-ProductID ]-BasePrice OPTIONAL )
                        CurrencyCode = VALUE #( products[ ProductID = item-ProductID ]-CurrencyCode OPTIONAL ) ) ).
  ENDMETHOD.


  METHOD calculatePromoPrice.
    " 1) Normal fiyat ve indirim oranini oku.
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        FIELDS ( RegularPrice DiscountPct )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " 2) Kampanya fiyati = Normal fiyat x (100 - indirim) / 100
    "    Ornek: 179,90 x (100 - 10) / 100 = 161,91
    "    Sonuc 2 ondalikli tutar alanina yazilirken otomatik yuvarlanir.
    MODIFY ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( PromoPrice )
        WITH VALUE #( FOR item IN items
                      ( %tky       = item-%tky
                        PromoPrice = item-RegularPrice * ( 100 - item-DiscountPct ) / 100 ) ).
  ENDMETHOD.


  METHOD validateItem.
    " 1) Kontrol edilecek kalemleri oku.
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item
        FIELDS ( ProductID RegularPrice DiscountPct )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    " 2) Her kalemin bagli oldugu kampanyayi bul.
    "    BY \_Promo : Kalemden kampanyaya gecis (association)
    "    LINK       : "Hangi kalem hangi kampanyaya bagli" eslesme tablosu
    "    Neden gerekli? Fiori'nin kalem mesajini dogru yerde (kampanya >
    "    kalem) gosterebilmesi icin mesaja yol (%path) eklememiz gerekiyor.
    READ ENTITIES OF zr_prm_promo_mk IN LOCAL MODE
      ENTITY Item BY \_Promo
        FROM CORRESPONDING #( items )
      LINK DATA(item_promo_links).

    LOOP AT items INTO DATA(item).

      " Bu kalemin kampanyasinin anahtari
      DATA(promo_tky) = item_promo_links[ KEY id source-%tky = item-%tky ]-target-%tky.

      " Onceki mesajlari temizle (bkz. validateDates aciklamasi)
      APPEND VALUE #( %tky        = item-%tky
                      %state_area = 'VALIDATE_ITEM' ) TO reported-item.

      " 3a) Urun bulunamadi: fillFromProduct normal fiyati dolduramamissa
      "     urun kodu ya bos ya da gecersizdir.
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

      " 3b) Indirim %0'dan buyuk, %100'den kucuk olmali.
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
