CLASS zcl_prm_cust_gen_mk DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    " Konsoldan F9 ile calistirilabilir sinif
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_prm_cust_gen_mk IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " Ayar tablolarini (durum ve tur metinleri) doldurur.
    " Kampanya verisine DOKUNMAZ; istedigin kadar tekrar calistirabilirsin.

    " 1) Eski ayar verisini temizle
    DELETE FROM zprm_status_mk.
    DELETE FROM zprm_ptype_mk.

    " 2) Durumlar, metinleri ve renkleri
    "    N = Yeni      -> 5 (mavi, bilgi)
    "    A = Onayli    -> 2 (sari, bekliyor)
    "    X = Yayinda   -> 3 (yesil, aktif)
    "    E = Bitti     -> 0 (gri, notr)
    INSERT zprm_status_mk FROM TABLE @( VALUE #(
      ( status = 'N' status_text = 'New'       criticality = 5 )
      ( status = 'A' status_text = 'Approved'  criticality = 2 )
      ( status = 'X' status_text = 'Published' criticality = 3 )
      ( status = 'E' status_text = 'Ended'     criticality = 0 ) ) ).

    " 3) Kampanya turleri
    INSERT zprm_ptype_mk FROM TABLE @( VALUE #(
      ( promo_type = 'P' type_text = 'Percent discount' )
      ( promo_type = 'F' type_text = 'Fixed price' )
      ( promo_type = 'B' type_text = 'Buy X pay Y' ) ) ).

    " @( VALUE #( ... ) ) : Ara degisken tanimlamadan, tabloyu dogrudan
    " INSERT komutunun icinde olusturur.

    out->write( |{ lines( VALUE string_table( ( `x` ) ) ) } Customizing data written: 4 statuses, 3 types.| ).
  ENDMETHOD.
ENDCLASS.
