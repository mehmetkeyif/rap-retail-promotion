// ============================================================================
// Urun listesi. Kalem ekranindaki urun alani icin deger yardimi (secim
// penceresi) olarak kullanilacak.
// ============================================================================
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Retail Product'
// Secim penceresinde arama kutusu calissin
@Search.searchable: true
define view entity ZI_PRM_PRODUCT_MK
  as select from zprm_prod_mk
{
      // Urun kodunun metni Description alaninda
      @ObjectModel.text.element: ['Description']
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Product'
  key product_id    as ProductID,

      // Arama kutusuna "shampoo" yazinca bu alanda da aransin.
      // fuzzinessThreshold: 0.8 = yazim hatalarina biraz toleransli arama
      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: 'Product Name'
      description   as Description,

      @EndUserText.label: 'Category'
      category      as Category,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      @EndUserText.label: 'Base Price'
      base_price    as BasePrice,

      @EndUserText.label: 'Currency'
      currency_code as CurrencyCode
}
