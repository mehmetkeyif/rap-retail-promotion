// ============================================================================
// Kampanya durumu: kod + metin + renk
// Iki gorevi var:
//  1) Kampanyaya baglanip durum kodunun yaninda metni ve rengi saglamak
//  2) Gerekirse acilir liste (deger yardimi) olarak kullanilmak
// ============================================================================
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion Status'
// #XS (cok kucuk) veri kumesi: Fiori deger yardimini acilir pencere yerine
// basit bir acilir liste (dropdown) olarak gosterir.
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_PRM_STATUS_MK
  as select from zprm_status_mk
{
      // Bu kodun metni StatusText alaninda: Fiori kod yerine metni gosterebilir
      @ObjectModel.text.element: ['StatusText']
      @EndUserText.label: 'Status'
  key status      as Status,

      // Bu alan bir metin (aciklama) alani
      @Semantics.text: true
      @EndUserText.label: 'Status Text'
      status_text as StatusText,

      @EndUserText.label: 'Criticality'
      criticality as Criticality
}
