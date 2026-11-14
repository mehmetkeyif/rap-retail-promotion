// ------------------------------------------------------------------
// Kampanya bazında ÖZET (KPI) görünümü
// DEĞİŞİKLİK: artık erişim kontrolü (DCL) uygulanıyor
// ------------------------------------------------------------------
// #CHECK -> bu görünüm için bir DCL rolü ARANIR ve uygulanır
// (#NOT_REQUIRED iken DCL hiç dikkate alınmıyordu)
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Promotion KPIs'

define view entity ZI_PRM_PROMO_KPI_MK
  as select from    zprm_promo_mk as Promo
    left outer join zprm_pitem_mk as Item on Item.parent_uuid = Promo.promo_uuid
{
  key Promo.promo_id                                        as PromoID,
      Promo.description                                     as Description,
      Promo.status                                          as Status,
      Promo.valid_from                                      as ValidFrom,
      Promo.valid_to                                        as ValidTo,
      Promo.currency_code                                   as CurrencyCode,

      // YENİ: kampanyayı oluşturan kullanıcı
      // DCL kuralı bu alana bakacak
      Promo.local_created_by                                as CreatedBy,

      count( distinct Item.item_uuid )                      as ItemCount,
      avg( Item.discount_pct as abap.dec( 5, 2 ) )          as AvgDiscountPct,
      max( Item.discount_pct )                              as MaxDiscountPct,
      sum( cast( Item.regular_price as abap.dec( 15, 2 ) ) ) as TotalRegular,
      sum( cast( Item.promo_price   as abap.dec( 15, 2 ) ) ) as TotalPromo,
      sum( cast( Item.regular_price as abap.dec( 15, 2 ) )
         - cast( Item.promo_price   as abap.dec( 15, 2 ) ) ) as TotalSaving
}
group by
  Promo.promo_id,
  Promo.description,
  Promo.status,
  Promo.valid_from,
  Promo.valid_to,
  Promo.currency_code,
  Promo.local_created_by      // YENİ alan GROUP BY'a da eklenmeli
