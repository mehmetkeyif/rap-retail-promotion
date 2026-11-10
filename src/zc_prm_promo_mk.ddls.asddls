// ============================================================================
// PROJEKSIYON GORUNUMU - Kampanya basligi
// ============================================================================
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion - Projection'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_PRM_PROMO_MK
  provider contract transactional_query
  as projection on ZR_PRM_PROMO_MK
{
  key PromoUUID,
      @Search.defaultSearchElement: true
      PromoID,
      @Search.defaultSearchElement: true
      Description,

      // YENI: Tur alani
      //  text.element        : Kodun metni PromoTypeText alaninda
      //  valueHelpDefinition : Bu alan icin ZI_PRM_PTYPE_MK listesinden
      //                        secim yapilsin (acilir liste)
      @ObjectModel.text.element: ['PromoTypeText']
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_PRM_PTYPE_MK', element: 'PromoType' } }]
      PromoType,
      // YENI: Baglantidan okunan metin. "_PromoType.TypeText" = baglanti
      // uzerinden diger gorunumun alanina erisim (path expression).
      _PromoType.TypeText    as PromoTypeText,

      ValidFrom,
      ValidTo,

      // YENI: Durum alani, metni ve rengi
      @ObjectModel.text.element: ['StatusText']
      Status,
      _Status.StatusText     as StatusText,
      _Status.Criticality    as StatusCriticality,

      CurrencyCode,
      LocalCreatedBy,
      LocalCreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      _Item : redirected to composition child ZC_PRM_PITEM_MK
}
