// ============================================================================
// PROJEKSIYON GORUNUMU - Kampanya kalemi
// ============================================================================
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion Item - Projection'
@Metadata.allowExtensions: true
define view entity ZC_PRM_PITEM_MK
  as projection on ZR_PRM_PITEM_MK
{
  key ItemUUID,
      ParentUUID,

      // YENI: Urun alani
      //  text.element        : Urun kodunun yaninda urun adi gosterilsin
      //  valueHelpDefinition : Alanin yanindaki simgeye basinca urun
      //                        listesi (arama kutulu secim penceresi) acilsin
      @ObjectModel.text.element: ['ProductName']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PRM_PRODUCT_MK', element: 'ProductID' } }]
      ProductID,
      // YENI: Urun adi, urun gorunumunden baglanti uzerinden okunur
      _Product.Description   as ProductName,

      RegularPrice,
      PromoPrice,
      DiscountPct,
      CurrencyCode,
      LocalLastChangedAt,
      _Promo : redirected to parent ZC_PRM_PROMO_MK,
      _Product
}
