" ======================================================================
" DAVRANIS ISLEYICI SINIFI (Behavior Handler)
" Davranis tanimindaki (ZR_PRM_PROMO_MK) kurallarin ABAP kodu burada
" yazilir. "lhc" = local handler class. Her varlik (Promotion, Item) icin
" ayri bir isleyici olabilir; simdilik sadece Promotion icin var.
" cl_abap_behavior_handler'dan miras almak zorunludur; RAP bu sinifin
" metotlarini dogru anda kendisi cagirir.
" ======================================================================
CLASS lhc_Promotion DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    " Davranis tanimindaki "authorization master ( global )" satirinin
    " karsiligi. Imza (FOR GLOBAL AUTHORIZATION ...) RAP tarafindan
    " belirlenir:
    "  requested_authorizations : Fiori'nin sordugu islemler
    "  result                   : Bizim izin/red cevabimiz
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Promotion
      RESULT result.

ENDCLASS.

CLASS lhc_Promotion IMPLEMENTATION.

  METHOD get_global_authorizations.
    " Bu deneme projesinde herkese her isleme izin veriyoruz.
    " Gercek projede burada AUTHORITY-CHECK ile kullanicinin rolu
    " kontrol edilir.
    " Sorulan her islem icin alan if_abap_behv=>mk-on degerinde gelir;
    " biz de auth-allowed (izin var) ile cevap veririz.

    " Yeni kampanya olusturma (Create butonu)
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

    " Kampanya degistirme
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.

    " Kampanya silme (Delete butonu)
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.

    " Taslak acma (Edit butonu)
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      result-%action-Edit = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
