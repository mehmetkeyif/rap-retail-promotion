// ============================================================================
// Kampanya turu: kod + metin. Tur alani icin acilir liste olarak kullanilir.
// ============================================================================
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion Type'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_PRM_PTYPE_MK
  as select from zprm_ptype_mk
{
      @ObjectModel.text.element: ['TypeText']
      @EndUserText.label: 'Promotion Type'
  key promo_type as PromoType,

      @Semantics.text: true
      @EndUserText.label: 'Type Text'
      type_text  as TypeText
}
