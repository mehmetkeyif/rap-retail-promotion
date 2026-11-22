// ------------------------------------------------------------------
// CDS TABLE FUNCTION: Kampanya kalemi kârlılığı
// Kendi içinde SQL YOK. Veriyi aşağıdaki AMDP metodu (SQLScript) üretir.
// ------------------------------------------------------------------
@EndUserText.label: 'Promotion profitability (AMDP)'
@AccessControl.authorizationCheck: #NOT_REQUIRED

// Mandant (client) yönetimi: HANA oturumundaki client değeri kullanılır
@ClientHandling.type: #CLIENT_DEPENDENT
@ClientHandling.algorithm: #SESSION_VARIABLE

define table function ZI_PRM_PROMO_PROFIT_TF
  // returns: fonksiyonun döndüreceği kolonlar (tablo yapısı)
  returns
  {
    // client ilk kolon olmak ZORUNDA (client-dependent fonksiyonlarda)
    key client        : abap.clnt;
    key item_uuid     : sysuuid_x16;
        promo_id      : abap.char(10);
        promo_type    : abap.char(1);
        product_id    : abap.char(10);
        // Fiyatlar düz ondalık (DEC); para birimi kuralına takılmamak için
        regular_price : abap.dec(15,2);
        promo_price   : abap.dec(15,2);
        discount_pct  : abap.dec(5,2);
        cost_price    : abap.dec(15,2);
        // --- AMDP'nin hesaplayacağı alanlar ---
        effective_price : abap.dec(15,2);  // tipe göre etkin satış fiyatı
        unit_margin     : abap.dec(15,2);  // etkin fiyat - maliyet
        margin_pct      : abap.dec(7,2);   // marj / etkin fiyat × 100
        profit_status   : abap.char(4);    // LOSS / LOW / OK
        currency_code   : abap.cuky;
  }
  // Veriyi üreten AMDP metodu (bir sonraki adımda yazacağız)
  implemented by method zcl_prm_profit_amdp_mk=>get_profitability;
  