// ============================================================================
// PROJEKSIYON GORUNUMU - Kampanya kalemi
// ============================================================================
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion Item - Projection'
@Metadata.allowExtensions: true

// Alt varlik oldugu icin "root" degil, sade "view entity".
// provider contract yazilmaz; kok varliktan devralir.
define view entity ZC_PRM_PITEM_MK
  as projection on ZR_PRM_PITEM_MK
{
  key ItemUUID,
      ParentUUID,
      ProductID,

      // Tutar alanlarinin para birimi bilgisi (@Semantics) alttaki
      // R gorunumunden otomatik devralinir; burada tekrar yazmaya gerek yok.
      RegularPrice,
      PromoPrice,
      DiscountPct,
      CurrencyCode,
      LocalLastChangedAt,

      // Ust kayda (kampanyaya) gecis, yine C katmanina yonlendiriliyor.
      _Promo : redirected to parent ZC_PRM_PROMO_MK,

      // Urun bilgisine gecis. Urun gorunumu ayri bir is nesnesi degil,
      // sadece okunan bir liste; yonlendirme gerekmez.
      _Product
}
