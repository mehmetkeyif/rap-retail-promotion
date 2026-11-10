// ============================================================================
// POS FIYAT BESLEMESI
// Kasalarin ihtiyac duydugu tek seyi verir: hangi urun, hangi tarihler
// arasinda, hangi fiyattan satilacak.
//
// Yalnizca YAYINDAKI (status = 'X') kampanyalar listelenir. Yeni, onayli
// ya da bitmis kampanyalar kasaya gitmez. "Publish" butonunun is anlami
// burada somutlasiyor: kampanya ancak yayinlaninca kasalar onu gorur.
// ============================================================================
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'POS Promotion Price Feed'
define view entity ZI_PRM_POS_PRICE_MK

  // Kalem tablosunu baslik tablosuyla birlestir (inner join):
  // her kalem satirina, bagli oldugu kampanyanin bilgileri eklenir.
  as select from zprm_pitem_mk as Item
    inner join   zprm_promo_mk as Promo
      on Promo.promo_uuid = Item.parent_uuid
{
  key Item.item_uuid       as ItemUUID,
      Promo.promo_id       as PromoID,
      Promo.description    as PromoDescription,
      Promo.promo_type     as PromoType,
      Item.product_id      as ProductID,
      Promo.valid_from     as ValidFrom,
      Promo.valid_to       as ValidTo,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Item.regular_price   as RegularPrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      Item.promo_price     as PromoPrice,
      Item.discount_pct    as DiscountPct,
      Item.currency_code   as CurrencyCode
}
// Yalnizca yayindaki kampanyalar
where Promo.status = 'X'
