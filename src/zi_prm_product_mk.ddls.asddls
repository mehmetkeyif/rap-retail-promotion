@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Retail Product'
define view entity ZI_PRM_PRODUCT_MK
  as select from zprm_prod_mk
{
  key product_id    as ProductID,
      description   as Description,
      category      as Category,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      base_price    as BasePrice,
      currency_code as CurrencyCode
}
