# Retail Promotion & Price Management (SAP RAP / ABAP Cloud)

A complete, draft-enabled SAP Fiori application built with the **ABAP RESTful Application Programming Model (RAP)** on **SAP BTP, ABAP Environment**. It covers the full lifecycle of retail price promotions — from planning to publishing promotion prices to point-of-sale (POS) systems.

The business scenario comes from real retail practice: store chains run many overlapping campaigns, and the cash register must always know **exactly one valid promotion price per product and day**.

![List Report](docs/images/list-report.png)

---

## Business Scenario

A retail chain's pricing team plans promotions (e.g. *"Haircare Week – 20% off"*), assigns products to them, gets them approved and finally publishes them to the stores. Stores' POS systems then pull the active promotion prices through an API.

```
  New (N) ──[Approve]──► Approved (A) ──[Publish]──► Published (X)
                                                        │
                                          POS systems read prices via Web API
```

---

## Features

| Area | What it does |
|---|---|
| **Fiori Elements UI** | List report and object page with search, filters, value helps and status colors |
| **Draft handling** | Users can save incomplete work and continue later; changes go live only on *Save* |
| **Automatic numbering** | Promotion IDs (`PR00000001`, …) are assigned on save |
| **Price calculation** | Selecting a product fills its regular price; the promotion price is calculated instantly by a **type-specific pricing strategy** (percent, fixed price, buy 3 pay 2) |
| **Business validations** | Date checks, product existence, discount range, **overlapping promotion check** |
| **Lifecycle actions** | *Approve* and *Publish* buttons with status-dependent enablement (feature control) |
| **POS Web API** | Read-only OData V4 API exposing prices of published promotions, also **by key date** (parameterized CDS) |
| **Promotion KPIs** | Aggregated KPIs per promotion (item count, average/max discount, total saving) with **row-level access control (DCL)** |
| **Profitability analysis** | Unit margin and LOSS / LOW / OK status per item, calculated twice — in **HANA with AMDP** and in **ABAP Objects** with the Strategy pattern — and cross-checked |
| **Unit tests** | 16 ABAP Unit tests: RAP transactional buffer doubles, CDS test doubles and pure OO logic tests |

### Key business rules

- End date must not be before start date.
- Discount must be between 0% and 100%.
- Promotion price depends on the promotion type: **P** percent → regular × (100 − discount) / 100 · **F** fixed price · **B** buy 3 pay 2 → regular × 2 / 3.
- **The same product cannot be in two promotions with overlapping dates** — otherwise the POS cannot decide which price applies. Checked both when items are added and when promotion dates change.
- A promotion without items cannot be approved.
- A promotion whose end date has passed cannot be published.
- Published and ended promotions are locked: no edit, delete or new items.

---

## Architecture

```mermaid
flowchart TB
    subgraph UI["Consumers"]
        FIORI["Fiori Elements App<br/>(OData V4 UI)"]
        POS["POS Systems<br/>(OData V4 Web API)"]
    end

    subgraph SRV["Service Layer"]
        SB1["ZUI_PRM_PROMO_O4_MK<br/>Service Binding"]
        SB2["ZAPI_PRM_POS_O4_MK<br/>Service Binding"]
    end

    subgraph PROJ["Projection Layer"]
        C["ZC_PRM_PROMO_MK / ZC_PRM_PITEM_MK<br/>+ Metadata Extensions (UI)"]
        API["ZI_PRM_POS_PRICE_MK<br/>(published prices only)"]
    end

    subgraph BO["Business Object Layer"]
        R["ZR_PRM_PROMO_MK (root) / ZR_PRM_PITEM_MK<br/>Behavior Definition + ZBP_R_PRM_PROMO_MK"]
    end

    subgraph DB["Persistence"]
        T["ZPRM_PROMO_MK / ZPRM_PITEM_MK<br/>+ draft tables"]
        M["ZPRM_PROD_MK / ZPRM_STATUS_MK / ZPRM_PTYPE_MK"]
    end

    FIORI --> SB1 --> C --> R --> T
    POS --> SB2 --> API --> T
    R -.value help / texts.-> M
```

### Development objects

| Layer | Objects |
|---|---|
| Database tables | `ZPRM_PROMO_MK`, `ZPRM_PITEM_MK`, `ZPRM_PROD_MK`, `ZPRM_STATUS_MK`, `ZPRM_PTYPE_MK`, draft tables `ZPRM_PROMO_D_MK`, `ZPRM_PITEM_D_MK` |
| CDS – business object | `ZR_PRM_PROMO_MK` (root), `ZR_PRM_PITEM_MK` (child) |
| CDS – master data / texts | `ZI_PRM_PRODUCT_MK`, `ZI_PRM_STATUS_MK`, `ZI_PRM_PTYPE_MK` |
| CDS – projection | `ZC_PRM_PROMO_MK`, `ZC_PRM_PITEM_MK` + metadata extensions |
| CDS – API | `ZI_PRM_POS_PRICE_MK`, `ZI_PRM_POS_KEYDATE_MK` (with parameter `P_KeyDate`, data element `ZPRM_KEYDATE_MK`) |
| CDS – analytics | `ZI_PRM_PROMO_KPI_MK` (aggregation) + access control `ZI_PRM_PROMO_KPI_MK` (DCL) |
| AMDP | Table function `ZI_PRM_PROMO_PROFIT_TF`, AMDP class `ZCL_PRM_PROFIT_AMDP_MK` |
| ABAP Objects | `ZIF_PRM_PRICE_STRATEGY_MK`, `ZCL_PRM_STRATEGY_PCT_MK`, `ZCL_PRM_STRATEGY_FIX_MK`, `ZCL_PRM_STRATEGY_BXGY_MK`, `ZCL_PRM_STRATEGY_FACTORY_MK`, `ZCL_PRM_PROFIT_CALC_MK` |
| Test classes | `ZTC_PRM_POS_KEYDATE_MK` (CDS test double), `ZTC_PRM_PROFIT_CALC_MK` (OO logic) |
| Behavior | `ZR_PRM_PROMO_MK` (managed, draft, strict 2), `ZC_PRM_PROMO_MK` (projection) |
| Behavior pool | `ZBP_R_PRM_PROMO_MK` – determinations, validations, actions, feature control, unit tests |
| Services | `ZUI_PRM_PROMO_MK` / `ZUI_PRM_PROMO_O4_MK` (UI), `ZAPI_PRM_POS_MK` / `ZAPI_PRM_POS_O4_MK` (Web API) |
| Utilities | `ZCL_PRM_DATA_GEN_MK` (demo data), `ZCL_PRM_CUST_GEN_MK` (status/type texts), `ZCL_PRM_COST_GEN_MK` (product cost prices) |

### RAP features used

`managed` implementation · `with draft` · `strict ( 2 )` · managed UUID numbering · determinations on modify / on save · validations with `%state_area` and `%path` messages · instance actions with result · instance feature control · global authorization · total ETag / ETag master · side effects · value helps and text associations · criticality · OData V4 UI and Web API bindings

---

## Profitability Analysis — AMDP vs. ABAP Objects

Each promotion item gets an **effective price**, a **unit margin** and a status. The same rule is implemented twice, in two technologies, and the results are compared row by row.

| Promotion type | Effective price |
|---|---|
| **P** – percent discount | regular × (100 − discount) / 100 |
| **F** – fixed price | promotion price as stored |
| **B** – buy 3 pay 2 | regular × 2 / 3 |

Unit margin = effective price − cost · Margin % = margin / effective price × 100 · Status: **LOSS** (margin < 0), **LOW** (< 10 %), **OK**.

### 1. In HANA — CDS table function + AMDP

`ZI_PRM_PROMO_PROFIT_TF` is read like any CDS view; its rows are produced by `ZCL_PRM_PROFIT_AMDP_MK=>GET_PROFITABILITY`, written in **SQLScript** and executed in the database (client handling via `SESSION_CONTEXT('CDS_CLIENT')`).

### 2. In ABAP — Strategy pattern

```mermaid
classDiagram
    class ZIF_PRM_PRICE_STRATEGY_MK {
        <<interface>>
        +get_effective_price(item) amount
        +get_description() string
    }
    ZIF_PRM_PRICE_STRATEGY_MK <|.. ZCL_PRM_STRATEGY_PCT_MK : P
    ZIF_PRM_PRICE_STRATEGY_MK <|.. ZCL_PRM_STRATEGY_FIX_MK : F
    ZIF_PRM_PRICE_STRATEGY_MK <|.. ZCL_PRM_STRATEGY_BXGY_MK : B (constructor X, Y)
    ZCL_PRM_STRATEGY_FACTORY_MK ..> ZIF_PRM_PRICE_STRATEGY_MK : creates
    ZCL_PRM_PROFIT_CALC_MK ..> ZCL_PRM_STRATEGY_FACTORY_MK : uses
    ZBP_R_PRM_PROMO_MK ..> ZCL_PRM_STRATEGY_FACTORY_MK : calculatePromoPrice
```

- A new promotion type needs **one new class and one line in the factory** — existing code stays unchanged (open/closed principle).
- The **RAP determination** `calculatePromoPrice` uses the same factory, so the pricing rule lives in one place.
- `calculate_item` has no database access, which makes it testable without doubles.
- Modern ABAP used throughout: `NEW`, `SWITCH`, `COND`, `REDUCE`, `FOR`, `CORRESPONDING … BASE`, `VALUE … OPTIONAL`, `xsdbool`, `IS INSTANCE OF`, string templates.

### Cross-check result

Running `ZCL_PRM_PROFIT_CALC_MK` (F9) compares both engines:

```
Kampanya   Ürün   Tip  Strateji          Etkin   Marj    Marj%  Durum  AMDP
PR00000001 P0003  P    Yüzde indirim      119.92   -7.50   -6.25  LOSS  AYNI
PR00000006 P0009  B    3 al 2 öde          36.60    3.66   10.00  OK    AYNI
PR00000008 P0002  B    3 al 2 öde          66.60   11.65   17.49  OK    AYNI
...
Toplam 11 kalem, 11 tanesi AMDP ile AYNI. Zararına satış: 2
```

### Findings

- **Bug found and fixed:** the RAP app calculated every promotion type as a percent discount, so a *buy 3 pay 2* item showed 46.67 instead of 36.60. Fixed by routing the determination through the strategy factory.
- **Data quality:** the stored promotion prices of one demo promotion were 1.00 too low; both engines recalculate from the rule and return the correct values.

---

## Testing

Business logic is covered by **ABAP Unit** tests in the behavior pool (`ZBP_R_PRM_PROMO_MK`, *Test Classes*). The tests use:

- `cl_botd_txbufdbl_bo_test_env` – transactional buffer test double, so behavior methods are tested in isolation without database writes
- `cl_osql_test_environment` – SQL test doubles for the overlap check

| Test | Rule verified |
|---|---|
| `dates_end_before_start_fails` | End date before start date is rejected |
| `dates_valid_range_passes` | A valid date range is accepted |
| `promo_price_is_calculated` | 89.90 with 10% discount = 80.91 |
| `approve_without_items_fails` | A promotion without items cannot be approved |
| `overlap_is_detected` | Overlapping promotions for the same product are detected |

Additional test classes:

| Class | Technique | Tests |
|---|---|---|
| `ZTC_PRM_POS_KEYDATE_MK` | `cl_cds_test_environment` (CDS test double) | only published promotions; days-left, urgency (CASE) and saving; empty result outside validity |
| `ZTC_PRM_PROFIT_CALC_MK` | pure OO logic, no database | each strategy, factory (`IS INSTANCE OF`), LOSS, boundary 10.00 % = OK, below 10 % = LOW, zero price |

Static code quality is checked with **ABAP Test Cockpit (ATC)**: no errors; the only warnings are deliberate full-table reads in the demo-data generators. Unnecessary full reads were replaced with `FOR ALL ENTRIES` (with an empty-table guard).

---

## POS Web API

Read-only OData V4 service returning the prices of **published** promotions only.

```http
GET /sap/opu/odata4/sap/zapi_prm_pos_o4_mk/srvd_a2x/sap/zapi_prm_pos_mk/0001/PromotionPrice?$filter=ProductID eq 'P0001'
```

```json
{
  "value": [
    {
      "PromoID": "PR00000001",
      "PromoDescription": "Haircare Week - 20% off",
      "ProductID": "P0001",
      "ValidFrom": "2026-11-09",
      "ValidTo": "2026-11-16",
      "RegularPrice": 89.9,
      "PromoPrice": 71.92,
      "DiscountPct": 20,
      "CurrencyCode": "TRY"
    }
  ]
}
```

In a productive setup the API would be exposed through a Communication Scenario and consumed by POS systems via a Communication Arrangement with a technical user.

---

## Screenshots

| | |
|---|---|
| ![Object page](docs/images/object-page.png) | ![Edit with value help](docs/images/value-help.png) |
| Object page with items | Product value help in draft mode |
| ![Overlap validation](docs/images/overlap-error.png) | ![Unit tests](docs/images/unit-tests.png) |
| Overlapping promotion is rejected | ABAP Unit test results |

---

## Installation

Requirements: SAP BTP ABAP Environment (trial or licensed), Eclipse with ABAP Development Tools and the abapGit plugin.

1. Create a package, e.g. `ZRAP_PROMO_MK`, under `ZLOCAL`.
2. In the **abapGit Repositories** view, link this repository to the package and **pull**.
3. Activate all objects.
4. Run `ZCL_PRM_CUST_GEN_MK` and `ZCL_PRM_DATA_GEN_MK` (F9) to create texts and demo data.
5. Publish the service bindings `ZUI_PRM_PROMO_O4_MK` and `ZAPI_PRM_POS_O4_MK`.
6. Open the preview of entity `Promotion` in `ZUI_PRM_PROMO_O4_MK`.

---

## Possible extensions

- Message class for translatable messages
- Number range object instead of `MAX()` for promotion IDs
- RAP business events on publish for push-based POS integration
- Editable fixed price for type F and recalculation of items when the promotion type changes
- Instance authorization based on store / category

---

## Related project

[joule-maintenance-agent](https://github.com/mehmetkeyif/joule-maintenance-agent): custom Joule agent and skill built with SAP Build Joule Studio, with an implementation guide, answer validation and hallucination tests.

---

## Author

**Mehmet Keyif** — SAP technical consultant with 25 years of experience in ABAP, S/4HANA conversion, data migration and retail POS / EDI integration.

[LinkedIn](https://www.linkedin.com/in/mehmet-keyif-21474b56)
