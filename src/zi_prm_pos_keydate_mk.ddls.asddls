// ------------------------------------------------------------------
// POS için ANAHTAR TARİHLİ kampanya fiyat görünümü
// Yeni öğrendiğimiz konular:
//   1) Parametre (with parameters)  -> görünüme dışarıdan değer verilir
//   2) Yerleşik fonksiyonlar        -> hesap veritabanında yapılır
//   3) CASE ifadesi                 -> koşula göre değer üretir
//   4) CAST                         -> tip dönüştürme
// ------------------------------------------------------------------
@AccessControl.authorizationCheck: #NOT_REQUIRED   // yetki (DCL) konusunu 3. adımda işleyeceğiz
@EndUserText.label: 'POS prices valid on key date'

define view entity ZI_PRM_POS_KEYDATE_MK
  // ---------------------------------------------------------------
  // PARAMETRE TANIMI
  // P_KeyDate: "Hangi tarihte geçerli fiyatları istiyorsun?"
  // @Environment.systemField: #SYSTEM_DATE -> ABAP SQL'den çağrılırken
  // parametre verilmezse sistem tarihi otomatik kullanılır
  // ---------------------------------------------------------------
  with parameters
    // Tip artık bir veri öğesi (DDIC) -> OData tipi ve etiketi buradan okur
    @Environment.systemField: #SYSTEM_DATE
    P_KeyDate : zprm_keydate_mk

  // Kalem tablosunu kampanya başlığıyla birleştiriyoruz (inner join)
  as select from zprm_pitem_mk as Item
    inner join   zprm_promo_mk as Promo on Promo.promo_uuid = Item.parent_uuid
{
      // ---------------- Anahtar ----------------
  key Item.item_uuid                                   as ItemUUID,

      // ---------------- Kampanya bilgileri ----------------
      Promo.promo_id                                   as PromoID,
      Promo.promo_type                                 as PromoType,

      // concat_with_space: iki metni araya 1 boşluk koyarak birleştirir
      // Örnek sonuç: "PR00000001 Haircare Week"
      concat_with_space( Promo.promo_id, Promo.description, 1 )
                                                       as PromoLabel,

      Item.product_id                                  as ProductID,
      Promo.valid_from                                 as ValidFrom,
      Promo.valid_to                                   as ValidTo,

      // ---------------- Parametreyi sonuca da yazıyoruz ----------------
      // $parameters.P_KeyDate -> parametrenin değerine böyle erişilir
      $parameters.P_KeyDate                            as KeyDate,

      // ---------------- Tarih fonksiyonu ----------------
      // dats_days_between( tarih1, tarih2 ) -> iki tarih arasındaki gün sayısı
      // Anahtar tarihten kampanya bitişine kaç gün kaldı?
      dats_days_between( $parameters.P_KeyDate, Promo.valid_to )
                                                       as DaysLeft,

      // ---------------- CASE ifadesi ----------------
      // Kalan güne göre aciliyet etiketi üretiyoruz.
      // CAST ile sonucun tipini sabitliyoruz (char 10)
      cast(
        case
          when dats_days_between( $parameters.P_KeyDate, Promo.valid_to ) <= 2
            then 'LAST_DAYS'    // son 2 gün
          when dats_days_between( $parameters.P_KeyDate, Promo.valid_to ) <= 7
            then 'THIS_WEEK'    // bu hafta bitiyor
          else 'ONGOING'        // devam ediyor
        end
      as abap.char(10) )                               as Urgency,

      // ---------------- Fiyatlar ----------------
      @Semantics.amount.currencyCode: 'CurrencyCode'
      Item.regular_price                               as RegularPrice,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Item.promo_price                                 as PromoPrice,

      Item.discount_pct                                as DiscountPct,

      // ---------------- Aritmetik + CAST ----------------
      // Müşterinin kazancı (TL) = normal fiyat - kampanya fiyatı
      // Para (CURR) alanlarını önce düz ondalık sayıya (DEC) çeviriyoruz,
      // böylece sonuç para birimi kuralına takılmadan hesaplanıyor
      cast( Item.regular_price as abap.dec( 15, 2 ) )
        - cast( Item.promo_price as abap.dec( 15, 2 ) )
                                                       as SavingAmount,

      Item.currency_code                               as CurrencyCode
}
// ---------------------------------------------------------------
// FİLTRE
// Yalnızca yayında (X) olan ve anahtar tarihte geçerli kampanyalar:
//   başlangıç <= anahtar tarih <= bitiş
// ---------------------------------------------------------------
where Promo.status     =  'X'
  and Promo.valid_from <= $parameters.P_KeyDate
  and Promo.valid_to   >= $parameters.P_KeyDate
