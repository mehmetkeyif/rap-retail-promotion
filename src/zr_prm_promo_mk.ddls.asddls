@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion Header - BO'
define root view entity ZR_PRM_PROMO_MK
  as select from zprm_promo_mk
  composition [0..*] of ZR_PRM_PITEM_MK as _Item

  // YENI: Durum ve tur metin tablolarina baglantilar.
  // [0..1] = her kampanyanin en fazla bir durum/tur metni var.
  // Baglanti (association) bir alan degil, "gerekirse oradan oku"
  // demektir. Bu yuzden taslak tablosuna yeni sutun gerekmez.
  association [0..1] to ZI_PRM_STATUS_MK as _Status
    on $projection.Status = _Status.Status
  association [0..1] to ZI_PRM_PTYPE_MK as _PromoType
    on $projection.PromoType = _PromoType.PromoType
{
  key promo_uuid            as PromoUUID,
      promo_id              as PromoID,
      description           as Description,
      promo_type            as PromoType,
      valid_from            as ValidFrom,
      valid_to              as ValidTo,
      status                as Status,
      currency_code         as CurrencyCode,
      @Semantics.user.createdBy: true
      local_created_by      as LocalCreatedBy,
      @Semantics.systemDateTime.createdAt: true
      local_created_at      as LocalCreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      _Item,
      // YENI
      _Status,
      _PromoType
}
