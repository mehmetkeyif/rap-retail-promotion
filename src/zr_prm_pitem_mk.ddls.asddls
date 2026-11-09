@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion Item - BO'
define view entity ZR_PRM_PITEM_MK
  as select from zprm_pitem_mk
  association to parent ZR_PRM_PROMO_MK as _Promo
    on $projection.ParentUUID = _Promo.PromoUUID
  association [0..1] to ZI_PRM_PRODUCT_MK as _Product
    on $projection.ProductID = _Product.ProductID
{
  key item_uuid             as ItemUUID,
      parent_uuid           as ParentUUID,
      product_id            as ProductID,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      regular_price         as RegularPrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      promo_price           as PromoPrice,
      discount_pct          as DiscountPct,
      currency_code         as CurrencyCode,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _Promo,
      _Product
}
