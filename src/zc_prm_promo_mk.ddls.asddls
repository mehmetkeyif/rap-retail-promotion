// ============================================================================
// PROJEKSIYON GORUNUMU - Kampanya basligi
// Alttaki is nesnesinin (ZR_PRM_PROMO_MK) Fiori uygulamasina acilan yuzu.
// ============================================================================

// Bu ornekte yetki kontrolu (DCL) yazmiyoruz; herkes tum kayitlari gorebilir.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion - Projection'

// Ekran anotasyonlarini (hangi alan listede, hangisi formda vb.) bu dosyaya
// degil, ayri bir "Metadata Extension" dosyasina yazacagiz. Bu satir buna
// izin verir. Boylece veri modeli ile ekran tasarimi birbirinden ayrilir.
@Metadata.allowExtensions: true

// Fiori listesinin ustundeki arama kutusu bu gorunumde calissin.
@Search.searchable: true

// "root" : Bu, projeksiyonun en ust varligi (kampanya basligi).
define root view entity ZC_PRM_PROMO_MK

  // provider contract transactional_query : Bu projeksiyonun hem okuma hem
  // degistirme (transactional) yapan bir uygulama icin oldugunu belirtir.
  // RAP buna gore kurallari kontrol eder.
  provider contract transactional_query

  // Hangi is nesnesinin uzerine kuruldugu
  as projection on ZR_PRM_PROMO_MK
{
  key PromoUUID,

      // Arama kutusuna yazilan metin bu iki alanda aranir.
      @Search.defaultSearchElement: true
      PromoID,
      @Search.defaultSearchElement: true
      Description,

      PromoType,
      ValidFrom,
      ValidTo,
      Status,
      CurrencyCode,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      // Kalemlere gecis. Alt katmandaki _Item, R katmanindaki kalem
      // gorunumunu gosteriyordu. Projeksiyonda bunu C katmanindaki kalem
      // gorunumune "yonlendiriyoruz" (redirected), yoksa uygulama
      // projeksiyonu atlayip cekirdege erisirdi.
      _Item : redirected to composition child ZC_PRM_PITEM_MK
}
