# SCD Data Generator — Comprehensive Guide

> Audience: **junior developers** new to the AdventureWorks Lakehouse pipeline.  
> Purpose: walk through *every* part of `scd_data_generator.ipynb` and show you how to drive **real, end-to-end SCD1 / SCD2 tests** through the bronze → silver → gold layers.

---

## Table of Contents

1. [What problem does this tool solve?](#1-what-problem-does-this-tool-solve)
2. [Refresher: SCD types in this project](#2-refresher-scd-types-in-this-project)
3. [Where the tool lives in the pipeline](#3-where-the-tool-lives-in-the-pipeline)
4. [Prerequisites](#4-prerequisites)
5. [Notebook anatomy — cell by cell](#5-notebook-anatomy--cell-by-cell)
   - [Cell 1 — Catalog widget](#cell-1--catalog-widget)
   - [Cell 2 — Imports, registry, helpers](#cell-2--imports-registry-helpers)
   - [Cell 3 — The interactive UI](#cell-3--the-interactive-ui)
   - [Cell 4 — Action implementations](#cell-4--action-implementations)
   - [Cell 5 — SCD validation helpers](#cell-5--scd-validation-helpers)
6. [Using the UI — step by step](#6-using-the-ui--step-by-step)
7. [The end-to-end test loop](#7-the-end-to-end-test-loop)
8. [Test scenario catalogue](#8-test-scenario-catalogue)
   - [SCD2 — tracked column change (Customer territory)](#scenario-a-scd2--tracked-column-change-customer-territory)
   - [SCD1 — untracked column change (Customer rowguid)](#scenario-b-scd1--untracked-column-change-customer-rowguid)
   - [Hard delete with invalidation](#scenario-c-hard-delete-with-invalidation)
   - [Multi-step history (3 versions)](#scenario-d-multi-step-history-3-versions)
   - [Insert then revert](#scenario-e-insert-then-revert)
   - [Product price change → snap_product](#scenario-f-product-price-change--snap_product)
   - [Employee promotion → snap_employee](#scenario-g-employee-promotion--snap_employee)
   - [Territory rep swap → snap_salesterritory](#scenario-h-territory-rep-swap--snap_salesterritory)
   - [No-op update (idempotency)](#scenario-i-no-op-update-idempotency)
   - [Re-insert after hard delete](#scenario-j-re-insert-after-hard-delete)
   - [Negative test — modifying a non-snapshotted table](#scenario-k-negative-test--modifying-a-non-snapshotted-table)
9. [Validation toolbox (queries & helpers)](#9-validation-toolbox-queries--helpers)
10. [Rolling back with Delta time travel](#10-rolling-back-with-delta-time-travel)
11. [Troubleshooting](#11-troubleshooting)
12. [Appendix A — full table → PK map](#appendix-a--full-table--pk-map)
13. [Appendix B — glossary](#appendix-b--glossary)

---

## 1. What problem does this tool solve?

When you build a dbt pipeline with **snapshots** (SCD2) and **dimension models** (SCD1 layered on top), it's hard to *prove* the SCD logic is correct unless you can:

- inject a brand-new row into bronze,
- modify a tracked column to force a new SCD2 version,
- modify an *untracked* column and confirm it does **not** create a version,
- hard-delete a row and confirm `dbt_valid_to` gets stamped.

Doing that by hand — typing `INSERT … VALUES (…)` SQL against every bronze table — is slow and error-prone.

**`scd_data_generator.ipynb`** is a Databricks notebook with an `ipywidgets`-based UI that:

- lets you pick **any of the 25 bronze tables**,
- preview live data,
- INSERT / UPDATE / DELETE rows with a form (no SQL required),
- auto-fills `BusinessKey`, `rowguid`, `ModifiedDate`,
- writes straight back to the Delta table so the next `dbt snapshot && dbt run` picks it up.

Once your change is in bronze, run dbt and use the validation helpers in Cell 5 to confirm the snapshot and the gold dimension behaved correctly.

---

## 2. Refresher: SCD types in this project

The AdventureWorks pipeline uses two SCD strategies:

| Type    | Where                                                         | How it's expressed                                                                   |
| ------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **SCD2** | `snapshots/snap_*.sql`                                       | dbt `snapshot` with `strategy='check'`, `check_cols=[…]`, `invalidate_hard_deletes=true`. Adds a new row when any `check_cols` value changes; stamps `dbt_valid_to` on the previous version. |
| **SCD1** | Inside `models/gold/dimensions/dim_*.sql`                    | Attributes joined in from `stg_*` / `int_*` views at run-time. Always reflects current bronze value — no history. |

There are **four** SCD2 snapshots:

| Snapshot              | Business key            | check_cols (tracked attributes)                                                                                              |
| --------------------- | ----------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `snap_customer`       | `customer_bk`           | `sales_territory_bk`, `customer_type`, `account_number`                                                                       |
| `snap_product`        | `product_bk`            | `product_name`, `list_price`, `standard_cost`, `product_subcategory_bk`, `product_category_bk`, `subcategory_name`, `category_name`, `product_status`, `color`, `size` |
| `snap_employee`       | `employee_bk`           | `job_title`, `department_bk`, `organization_node`, `organization_level`, `pay_rate`, `pay_frequency`, `is_salaried`, `is_current`, `marital_status` |
| `snap_salesterritory` | `sales_territory_bk`    | `territory_name`, `country_region_code`, `territory_group`, `current_sales_person_bk`                                          |

> 🧠 **Mental model.** A change to a `check_col` ⇒ new SCD2 version. A change to anything else ⇒ silently overwritten (SCD1 behaviour at the dimension layer).

---

## 3. Where the tool lives in the pipeline

```
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ This notebook (scd_data_generator.ipynb)  ──── writes Delta MERGE/APPEND │
   │                                                                         │
   │                       ▼                                                 │
   │   adventureworks_dev.bronze.<Table>   ◄── you mutate this directly      │
   │                       │                                                 │
   │            (dbt run-operation freshness)                                │
   │                       ▼                                                 │
   │   silver.stg_<table>             (views, no history)                    │
   │                       ▼                                                 │
   │   gold.snap_<entity>             (SCD2 — dbt snapshot)                  │
   │                       ▼                                                 │
   │   gold.dim_<entity>              (SCD2 + SCD1 attributes joined in)     │
   └─────────────────────────────────────────────────────────────────────────┘
```

The notebook only touches **bronze**. Everything downstream is rebuilt by dbt.

---

## 4. Prerequisites

1. The bronze layer is already populated. Run `notebooks/bronze_bootstrap.ipynb` once.
2. `dbt` is installed and `profiles.yml` is pointed at the same workspace.
3. The Databricks cluster running this notebook has:
   - DBR 13+ (for Delta DML),
   - `ipywidgets` available (built into the Databricks Python kernel),
   - permission to write to `adventureworks_dev.bronze.*`.
4. You know which **catalog** you're targeting. The default is `adventureworks_dev`. The `dbt_project.yml` toggles between `_dev` and `_prod` via `target.name`.

> ⚠️ **Never run this notebook against the `_prod` catalog.** It mutates raw bronze data.

---

## 5. Notebook anatomy — cell by cell

Open `notebooks/scd_data_generator.ipynb` in Databricks. There are five executable groups.

### Cell 1 — Catalog widget

```python
dbutils.widgets.text("catalog", "adventureworks_dev")
catalog_name = dbutils.widgets.get("catalog") or "adventureworks_dev"
print(f"Using catalog: {catalog_name}")
```

- Adds a text widget at the top of the notebook so you can flip catalog without editing code.
- The `or` fallback guards against an empty string.
- All subsequent cells reference `catalog_name`, so **you must run Cell 1 first**.

### Cell 2 — Imports, registry, helpers

```python
from datetime import datetime, timezone
import uuid

import ipywidgets as widgets
from IPython.display import display, clear_output
from pyspark.sql import functions as F
from pyspark.sql.types import StringType
```

Standard imports plus `ipywidgets` for the UI.

```python
TABLES = {
    "Customer":              {"pk": "CustomerID"},
    "SalesOrderHeader":      {"pk": "SalesOrderID"},
    ...
}
```

A registry of **all 25 bronze tables** mapped to their primary-key column. Adding a new bronze table = add one line here. (See [Appendix A](#appendix-a--full-table--pk-map).)

Helpers:

| Helper                          | Purpose                                                                                                    |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `now_ts()`                      | Returns the current UTC timestamp as `'YYYY-MM-DD HH:MM:SS'` for stamping `ModifiedDate`.                  |
| `full_table(name)`              | Builds the 3-part name `catalog.bronze.<table>`.                                                            |
| `read_table(name)`              | `spark.table(...)` shorthand.                                                                              |
| `get_columns(name)`             | Returns the column list straight from the live Delta schema — so the form always matches reality.          |
| `get_max_pk(name)`              | Casts the PK column to int and returns `MAX(pk)`. Used to suggest the next free ID for INSERTs.            |

### Cell 3 — The interactive UI

This is where most of the visual code lives.

**Top controls.** A dropdown for table, a slider for preview row count, a Preview button, and a radio group for the action.

```python
w_table   = widgets.Dropdown(options=sorted(TABLES.keys()), value="Customer", …)
w_action  = widgets.RadioButtons(options=[
              "INSERT new row",
              "UPDATE existing row",
              "DELETE existing row",
            ], …)
```

**Dynamic field area.** `build_fields()` rebuilds the form whenever you change the table or action.

- For **INSERT**: one text box per column.
- For **UPDATE**: a PK target text box at the top + one text box per column (blank means *keep existing*).
- For **DELETE**: just the PK target text box.

The function also adds hints to placeholders:

- `(next available: 21001)` for the PK column on INSERT,
- `(auto-generated if blank)` for `rowguid`,
- `(auto-set to now if blank)` for `ModifiedDate`.

**Observers.** `w_table.observe(build_fields, names="value")` re-renders the form when you change the dropdown. Same for the action radio.

**Execute button.** Dispatches to `_do_insert`, `_do_update`, or `_do_delete` based on the radio value. Output is wrapped in a single `out_status` Output widget so re-clicks replace prior output.

**Final `display(...)` call.** Assembles all widgets into a single `VBox` and renders it.

### Cell 4 — Action implementations

This cell defines the three action functions. **It must be run before clicking ▶ Execute.**

```python
from delta.tables import DeltaTable
```

(`DeltaTable` is imported in case you want to extend the helpers to use `MERGE` later. The basic actions use SQL DML.)

#### `_collect_field_values()`

Iterates over the per-column text widgets and returns `{column: value_or_None}`. Empty strings collapse to `None` so we can distinguish "leave alone" from "set to empty".

#### `_do_insert(table, pk, ft)`

1. Auto-assigns the PK from `get_max_pk(table)+1` if blank.
2. Generates a new uppercase UUID for `rowguid` if blank.
3. Stamps `ModifiedDate = now_ts()` if blank.
4. Re-reads the current columns from the Delta schema and builds a single-row dict in that order — guarantees schema alignment.
5. Appends with `df.write.format("delta").mode("append").saveAsTable(ft)`.

> Bronze tables are all-string (see `bronze_bootstrap.ipynb`), so we don't have to worry about type casting on the way in.

#### `_do_update(table, pk, ft)`

1. Validates the PK target was supplied.
2. Drops blank fields from the update set (so you only touch what you intend to change).
3. **Always** bumps `ModifiedDate` to now — important for the dbt snapshot's `updated_at` column.
4. Generates a parameterised `UPDATE … SET col=val,… WHERE pk='…'` and executes via `spark.sql`.

> ⚠️ Values are wrapped in single quotes. Don't put single-quote characters into the value text boxes; if you must, the workaround is to run the SQL by hand.

#### `_do_delete(table, pk, ft)`

1. Validates the PK target.
2. Counts affected rows first so we can warn if the PK doesn't exist.
3. `DELETE FROM ft WHERE pk='…'`.
4. Reminds you to run `dbt snapshot` so the snapshot picks up the hard delete and stamps `dbt_valid_to` (thanks to `invalidate_hard_deletes=true`).

### Cell 5 — SCD validation helpers

Three helper functions you can call after running dbt:

| Helper                                       | Use                                                                              |
| -------------------------------------------- | -------------------------------------------------------------------------------- |
| `show_scd_history(snap, bk_col, bk_value)`   | Prints every version (in chronological order) of one business key from a snapshot. |
| `show_open_rows(snap)`                       | Quick count of "currently open" rows (`dbt_valid_to IS NULL`).                   |
| `check_no_overlap(snap, bk_col)`             | Asserts no business key has more than one open row. Should always be 0.           |

The cell ends with a commented-out example block. Uncomment and edit the IDs to point at the rows you've been mutating.

---

## 6. Using the UI — step by step

> Follow this exact sequence the first time.

1. **Attach** the notebook to a running cluster.
2. **Run Cell 1** — confirm the printed catalog is what you expect.
3. **Run Cell 2** — should print `Helpers loaded. Proceed to Cell 3.`
4. **Run Cell 4** — yes, before Cell 3. The button in Cell 3 calls functions defined in Cell 4, so they must exist first. (You can also run them in order if you re-run Cell 3 after.)
5. **Run Cell 3** — the widget panel renders.
6. Pick a **Table** in the dropdown.
7. Click **🔍 Preview table** to see the current contents.
8. Choose an **Action**.
9. Fill in the relevant fields:
   - INSERT — leave PK/`rowguid`/`ModifiedDate` blank to auto-fill.
   - UPDATE — fill in the **target PK** first, then only the columns you want to change.
   - DELETE — fill in only the **target PK**.
10. Click **▶ Execute**. Read the status output for confirmation or errors.
11. Run dbt (see [section 7](#7-the-end-to-end-test-loop)).
12. Use Cell 5 helpers to validate.

> 💡 You can change the action or table at any time and the form re-renders automatically.

---

## 7. The end-to-end test loop

From your terminal in the repo root:

```bash
# 1. Mutate bronze in the notebook UI (Cell 3 → ▶ Execute).

# 2. Refresh staging views (cheap — views).
dbt run --select silver.staging

# 3. Update SCD2 history (this is where the magic happens).
dbt snapshot

# 4. Rebuild downstream dimensions.
dbt run --select gold

# 5. (optional) run tests.
dbt test --select gold snapshots
```

For the impatient, the lazy one-liner:

```bash
dbt build --select +dim_customer
# or
dbt build --select +dim_product
```

`dbt build` runs models, snapshots, and tests in DAG order.

---

## 8. Test scenario catalogue

Each scenario lists: **goal**, **steps**, **expected result**, **how to verify**. Replace IDs as needed.

### Scenario A — SCD2: tracked column change (Customer territory)

**Goal.** Confirm a change to `TerritoryID` on a Customer row produces a new SCD2 version in `snap_customer` and the previous version's `dbt_valid_to` gets stamped.

1. UI: Table = `Customer`, Action = `UPDATE existing row`.
2. Target PK: `29485`. New `TerritoryID`: `5`. Leave other fields blank.
3. Click ▶ Execute.
4. Terminal: `dbt run --select stg_customer && dbt snapshot --select snap_customer && dbt run --select dim_customer`.
5. In notebook Cell 5:

```python
show_scd_history(f"{catalog_name}.gold.snap_customer", "customer_bk", 29485)
```

**Expected.** Two rows: the original with `dbt_valid_to` now non-null, and a new row with the new `sales_territory_bk` and `dbt_valid_to IS NULL`.

### Scenario B — SCD1: untracked column change (Customer rowguid)

**Goal.** Confirm a change to `rowguid` does **not** produce a new SCD2 version — it's not in `check_cols`.

1. UI: UPDATE Customer `29485`, set `rowguid` to a new GUID.
2. Run dbt.
3. `show_scd_history(...)` — count of rows for this `customer_bk` should be **unchanged** from before.

> This proves the snapshot is correctly ignoring untracked columns. The `rowguid` itself doesn't surface in `dim_customer`, but you can verify the bronze row changed:
> ```sql
> SELECT rowguid FROM adventureworks_dev.bronze.Customer WHERE CustomerID = 29485
> ```

### Scenario C — Hard delete with invalidation

**Goal.** Confirm `invalidate_hard_deletes=true` works.

1. UI: DELETE Customer `29485`.
2. Run dbt (`dbt snapshot && dbt run --select dim_customer`).
3. `show_scd_history(...)` — the most recent row should now have `dbt_valid_to` set to the snapshot run time. **No new row** is added; the existing open version is just closed.

> Note the dim now no longer has an `is_current = true` row for `customer_bk = 29485`.

### Scenario D — Multi-step history (3 versions)

**Goal.** Build a 3-version history and confirm dates chain correctly.

1. INSERT a new Customer (let auto-PK pick e.g. `30000`). Set `TerritoryID = 1`.
2. Run dbt. Expect 1 open version.
3. UPDATE Customer `30000`, set `TerritoryID = 2`.
4. Run dbt. Expect 2 versions; v1 closed, v2 open.
5. UPDATE Customer `30000`, set `TerritoryID = 3`.
6. Run dbt. Expect 3 versions.

Verify with:

```python
show_scd_history(f"{catalog_name}.gold.snap_customer", "customer_bk", 30000)
```

The `dbt_valid_from` of each row should equal the `dbt_valid_to` of the previous row.

### Scenario E — Insert then revert

**Goal.** Confirm reverting a column to its original value still creates a new SCD2 version (because the value *changed* at one point in time).

1. INSERT Customer with `TerritoryID = 1`.
2. dbt → 1 version.
3. UPDATE `TerritoryID = 2`.
4. dbt → 2 versions.
5. UPDATE `TerritoryID = 1` again.
6. dbt → **3 versions**. (Each transition through `check_cols` makes history; final value equals the first, but that's just data — the time axis is what matters.)

### Scenario F — Product price change → `snap_product`

**Goal.** A change to `ListPrice` should create a new `snap_product` version.

1. UI: Table = `Product`, UPDATE, target PK = `707` (Sport-100 Helmet, Red).
2. Field `ListPrice` = `39.99` (was `34.99`).
3. dbt → `show_scd_history(f"{catalog_name}.gold.snap_product", "product_bk", 707)` shows two versions.

> Bonus: change `Color` from `Red` to `Crimson` to verify two `check_cols` changing in one bronze row still results in one new snapshot row (not two).

### Scenario G — Employee promotion → `snap_employee`

**Goal.** Change `JobTitle` on Employee `BusinessEntityID = 4` and verify the dimension reflects the new title for new fact joins.

1. UI: Table = `Employee`, UPDATE, target PK = `4`, `JobTitle = 'Senior Engineering Manager'`.
2. dbt build.
3. Validate:

```python
show_scd_history(f"{catalog_name}.gold.snap_employee", "employee_bk", 4)
```

### Scenario H — Territory rep swap → `snap_salesterritory`

**Goal.** Change the assigned sales person for a territory (`current_sales_person_bk` is a tracked column).

This is tricky because `current_sales_person_bk` is *derived* in `int_territory_current` from `SalesTerritoryHistory`. To force it to change, INSERT a new row into `SalesTerritoryHistory`:

1. UI: Table = `SalesTerritoryHistory`, INSERT.
2. Fields:
   - `BusinessEntityID = 280` (an existing sales person)
   - `TerritoryID = 1`
   - `StartDate = 2026-05-27 00:00:00`
   - `EndDate` = leave blank
   - `rowguid` / `ModifiedDate` = blank (auto)
3. dbt build → `show_scd_history(... "snap_salesterritory", "sales_territory_bk", 1)` should add a new version with the new `current_sales_person_bk = 280`.

### Scenario I — No-op update (idempotency)

**Goal.** Confirm UPDATEs that change *only* untracked columns do not create new SCD2 versions, even if you run `dbt snapshot` multiple times.

1. UI: UPDATE Customer `29485`, change *only* `rowguid` (a non-`check_col`).
2. `dbt snapshot` twice.
3. `show_scd_history(...)` row count should be **unchanged**.

### Scenario J — Re-insert after hard delete

**Goal.** Confirm re-inserting a previously deleted business key starts a fresh version line.

1. INSERT Customer `99999` → dbt → 1 open version.
2. DELETE Customer `99999` → dbt → 0 open versions; history shows the closed version.
3. INSERT Customer `99999` again with different `TerritoryID`.
4. dbt → 2 history rows total, **one** open. The dbt snapshot will treat this as a reactivation.

### Scenario K — Negative test: modifying a non-snapshotted table

**Goal.** Confirm changes to a table without a snapshot (e.g. `Address`) flow straight to silver/gold without versioning.

1. UI: Table = `Address`, UPDATE, change `City` for `AddressID = 1`.
2. `dbt run --select silver gold`. **No snapshot needed** — there is no `snap_address`.
3. Query `dim_customer.city` (joined in via `int_customer_addresses`): the city should be updated for all current customers at that address, with **no history**.

This is the SCD1 behaviour layered on top of the SCD2 dim.

---

## 9. Validation toolbox (queries & helpers)

### a) Inspect the full history of a business key

```python
show_scd_history(
    f"{catalog_name}.gold.snap_customer",
    bk_col="customer_bk",
    bk_value=29485,
)
```

Returned columns of interest: `dbt_valid_from`, `dbt_valid_to`, the `check_cols`, and the unique `dbt_scd_id`.

### b) Count open rows per snapshot

```python
for snap, bk in [
    ("snap_customer",       "customer_bk"),
    ("snap_product",        "product_bk"),
    ("snap_employee",       "employee_bk"),
    ("snap_salesterritory", "sales_territory_bk"),
]:
    print(snap)
    show_open_rows(f"{catalog_name}.gold.{snap}")
```

Open-row count should equal "live" bronze row count for that business key (minus hard deletes).

### c) Assert no overlapping open rows

```python
check_no_overlap(f"{catalog_name}.gold.snap_customer", "customer_bk")
```

Anything non-zero here is a bug in the snapshot definition.

### d) Sanity SQL you can run in Databricks SQL editor

```sql
-- A: timeline of one business key
SELECT customer_bk, sales_territory_bk, customer_type, account_number,
       dbt_valid_from, dbt_valid_to
FROM   adventureworks_dev.gold.snap_customer
WHERE  customer_bk = 29485
ORDER  BY dbt_valid_from;

-- B: which keys have history (>1 row)?
SELECT customer_bk, COUNT(*) AS n_versions
FROM   adventureworks_dev.gold.snap_customer
GROUP  BY customer_bk
HAVING COUNT(*) > 1
ORDER  BY n_versions DESC;

-- C: latest version vs gold dim parity
SELECT s.customer_bk, s.sales_territory_bk AS snap_territory,
       d.sales_territory_bk AS dim_territory
FROM   adventureworks_dev.gold.snap_customer s
JOIN   adventureworks_dev.gold.dim_customer  d ON d.customer_bk = s.customer_bk
WHERE  s.dbt_valid_to IS NULL AND d.is_current = true
   AND s.sales_territory_bk <> d.sales_territory_bk;   -- expect empty
```

---

## 10. Rolling back with Delta time travel

If you make a mess, every bronze table is Delta — you can restore.

```sql
-- See history
DESCRIBE HISTORY adventureworks_dev.bronze.Customer;

-- Roll back to a specific version
RESTORE TABLE adventureworks_dev.bronze.Customer TO VERSION AS OF 7;
```

After rolling back bronze, re-run `dbt snapshot` to re-close any rows that were artificially "opened" by your test mutations.

> ⚠️ Restoring bronze does **not** roll back the snapshot table. You may need to manually delete bad rows from `snap_*` if you want a clean slate. See the next section.

If you want a hard reset of a snapshot (dev only!):

```sql
DROP TABLE adventureworks_dev.gold.snap_customer;
```

Then run `dbt snapshot --select snap_customer` to rebuild it from the (now-clean) bronze.

---

## 11. Troubleshooting

| Symptom                                                                        | Likely cause                                                                                                                          | Fix                                                                                                |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `NameError: name '_do_insert' is not defined`                                  | You clicked ▶ Execute before running Cell 4.                                                                                          | Run Cell 4 (and Cell 2) once, then click Execute again.                                            |
| Form has no fields                                                             | Cell 3 ran before Cell 2 (helpers not loaded) or table dropdown picked a removed table.                                               | Re-run Cell 2 then Cell 3.                                                                         |
| `AnalysisException: Table or view not found`                                   | Wrong catalog in the widget, or `bronze_bootstrap.ipynb` hasn't been run.                                                             | Fix the widget value, re-run Cell 1.                                                               |
| INSERT succeeds but the row never shows up in `dim_customer`                   | You skipped `dbt snapshot`.                                                                                                           | `dbt build --select +dim_customer`.                                                                |
| Snapshot adds a row for an untracked column change                             | The column *is* in `check_cols` — re-read `snap_*.sql`.                                                                               | Either it's expected, or amend the snapshot definition.                                            |
| `check_no_overlap` returns >0 rows                                             | Two writes landed within the same `dbt snapshot` run with the same `dbt_valid_from`. Usually a race in dev.                          | Investigate timing; consider a unique tests on `dbt_scd_id`.                                       |
| DELETE in UI removed the row but `dbt_valid_to` is still null                  | `dbt snapshot` not run yet, or `invalidate_hard_deletes` is `false` in the snapshot.                                                  | Re-check `snap_*.sql` config, run `dbt snapshot`.                                                  |
| Single-quote (`'`) in a value crashes UPDATE                                   | Naïve string quoting in `_do_update`.                                                                                                 | Run the equivalent SQL with parameterised escaping in a SQL cell.                                  |
| `ModifiedDate` doesn't change on UPDATE                                        | You typed a value into `ModifiedDate` manually. The code only auto-bumps if all updates leave it blank. Actually `_do_update` always sets it — check you ran the latest Cell 4. | Re-run Cell 4 to get the latest helpers.                                                           |

---

## Appendix A — full table → PK map

| Bronze table              | PK column            | Has SCD2 snapshot?         |
| ------------------------- | -------------------- | -------------------------- |
| Customer                  | CustomerID           | ✅ via `snap_customer`     |
| SalesOrderHeader          | SalesOrderID         | ❌ (fact source)           |
| SalesOrderDetail          | SalesOrderDetailID   | ❌ (fact source)           |
| SalesTerritory            | TerritoryID          | ✅ via `snap_salesterritory` |
| SalesTerritoryHistory     | BusinessEntityID*    | indirect — drives `snap_salesterritory` |
| SalesPerson               | BusinessEntityID     | indirect                   |
| SpecialOffer              | SpecialOfferID       | ❌                         |
| SpecialOfferProduct       | SpecialOfferID*      | ❌                         |
| CurrencyRate              | CurrencyRateID       | ❌                         |
| ShipMethod                | ShipMethodID         | ❌                         |
| CreditCard                | CreditCardID         | ❌                         |
| Store                     | BusinessEntityID     | indirect — joined into `dim_customer` (SCD1) |
| Employee                  | BusinessEntityID     | ✅ via `snap_employee`     |
| EmployeePayHistory        | BusinessEntityID*    | indirect                   |
| EmployeeDepartmentHistory | BusinessEntityID*    | indirect                   |
| BusinessEntityAddress     | BusinessEntityID*    | ❌ (SCD1 in dim_customer)  |
| Person                    | BusinessEntityID     | ❌ (SCD1 in dim_customer)  |
| PersonPhone               | BusinessEntityID*    | ❌                         |
| EmailAddress              | BusinessEntityID*    | ❌                         |
| Address                   | AddressID            | ❌ (SCD1 in dim_customer)  |
| StateProvince             | StateProvinceID      | ❌                         |
| Product                   | ProductID            | ✅ via `snap_product`      |
| ProductSubcategory        | ProductSubcategoryID | indirect — feeds `snap_product` |
| ProductCategory           | ProductCategoryID    | indirect — feeds `snap_product` |
| ProductListPriceHistory   | ProductID*           | ❌                         |
| ProductInventory          | ProductID*           | ❌                         |

\* These tables have composite natural keys in the source system. The tool uses the listed column for matching, which works for single-row INSERT/UPDATE/DELETE in this dev/test context — but be aware that an UPDATE on `SalesTerritoryHistory` where `BusinessEntityID` is shared by multiple rows will touch all of them. For surgical edits to composite-key tables, run the SQL manually.

---

## Appendix B — glossary

- **Business key (BK).** The natural identifier of an entity in the source system, e.g. `CustomerID`. In silver, columns are renamed to `_bk` suffix (e.g. `customer_bk`).
- **Surrogate key (SK).** A hash key generated in gold for fact joins (`customer_sk`). Different per SCD2 version.
- **`check_cols`.** The list of tracked attributes in a dbt `snapshot`. A change to any of them creates a new SCD2 row.
- **`dbt_valid_from` / `dbt_valid_to`.** SCD2 validity window. Open row ⇒ `dbt_valid_to IS NULL`.
- **`dbt_scd_id`.** Unique surrogate per snapshot row, hashed from the BK and `dbt_valid_from`.
- **`invalidate_hard_deletes`.** Snapshot config: when a BK disappears from the source query, close its open row.
- **SCD1.** Overwrite — no history. In this project, achieved by joining `stg_*` views into the dim model.
- **SCD2.** Insert-on-change with a validity window — in this project, every `snap_*.sql` snapshot.
- **Hard delete.** A row physically removed from the source. Compare with *soft delete* (a flag column).

---

*Last updated: tool version 1.0 — paired with `notebooks/scd_data_generator.ipynb`.*
