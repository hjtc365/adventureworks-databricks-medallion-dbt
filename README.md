# AdventureWorks — Databricks Medallion Lakehouse with dbt

An end-to-end, production-shaped implementation of the **AdventureWorks 2025** sample database as a **Bronze → Silver → Gold medallion lakehouse** on **Databricks Free Edition**, built with **dbt Core** and the **dbt-databricks** adapter.

This project is built to reflect patterns commonly used in real-world data warehouses,  including a Kimball star schema, SCD Type 2 history, incremental `MERGE` loads, a data-quality test suite, and environment-specific schema isolation. The goal is to showcase the kinds of design and engineering decisions you would typically encounter in a production analytics platform.

---

## What this project demonstrates

| Capability | Where it shows up |
|------------|-------------------|
| **Medallion architecture** | `models/bronze` (sources) → `models/silver` (staging + intermediate) → `models/gold` (dims, facts, marts) |
| **Dimensional modelling (Kimball)** | 7 conformed dimensions, a fact at sales-order-line grain, a pre-aggregated BI mart |
| **Slowly Changing Dimensions (Type 2)** | dbt snapshots + SCD2 dimensions for Product, Employee, SalesTerritory, with surrogate/business-key separation and an "Unknown member" safety net |
| **Point-in-time attribution** | Fact joins to the dimension version that was current when each order was placed |
| **Incremental processing** | `MERGE`-based incremental models for high-volume order header/detail and the fact table |
| **Advanced modelling patterns** | Junk dimension for low-cardinality flags, allocated semi-additive measures (freight/tax) at line grain |
| **Testing as a data contract** | 558 tests — built-ins, `dbt_utils`, `dbt_expectations`, a custom SCD2 overlap test, and singular reconciliation tests |
| **Engineering for multiple environments** | Custom `generate_schema_name` macro isolates `dev`, `ci`, and `prod` into separate schemas without collisions |
| **Self-bootstrapping ingestion** | A single Databricks notebook downloads the raw CSVs and lands them as Delta in Bronze |
| **Observability & docs** | `on-run-start`/`on-run-end` hooks, `persist_docs` to Unity Catalog, and a browsable `dbt docs` lineage site |

---

## Architecture

```mermaid
flowchart LR
    subgraph Bronze["Bronze - raw Delta (loaded by notebook)"]
        B[22 source tables<br/>external Delta]
    end
    subgraph Silver["Silver - cleaned & conformed"]
        S1[22 staging models<br/>views + 2 incremental MERGE]
        S2[6 intermediate models<br/>enrichment & joins]
        SN[3 snapshots<br/>SCD2 'check' strategy]
    end
    subgraph Gold["Gold - dimensional model"]
        D[7 dimensions<br/>Type 1 + SCD2]
        F[fct_sales_detail<br/>incremental MERGE]
        M[mart_sales_summary<br/>pre-aggregated BI table]
    end

    B --> S1 --> S2
    S1 --> SN --> D
    S2 --> D
    D --> F --> M
```

| Layer | Contents | Materialisation |
|-------|----------|-----------------|
| **Bronze** | 22 source tables | external Delta (loaded by `bronze_bootstrap.ipynb`) |
| **Silver** | 22 staging + 6 intermediate | `view` + 2 incremental `MERGE` (`stg_sales_order_header`, `stg_sales_order_detail`) |
| **Snapshots** | 3 (Product, Employee, SalesTerritory) | dbt snapshot, `check` strategy |
| **Gold** | 7 dims, 1 fact, 1 mart | `table` + incremental `MERGE` on the fact |
| **Tests** | 558 | built-in + `dbt_utils` + `dbt_expectations` + 1 custom + 3 singular |

---

## Tech stack

- **dbt Core** with the **dbt-databricks** adapter (tested on dbt-core 1.11 / dbt-databricks 1.12; `dbt-databricks>=1.10` is recommended)
- **Databricks Free Edition** — serverless SQL warehouse + Unity Catalog
- **Delta Lake** storage format throughout
- dbt packages: [`dbt_utils`](https://github.com/dbt-labs/dbt-utils), [`dbt_expectations`](https://github.com/calogica/dbt-expectations), [`codegen`](https://github.com/dbt-labs/dbt-codegen)

---

## Project structure

```text
adventureworks-databricks-medallion-dbt/
├── dbt_project.yml          # project config, materialisations, persist_docs, hooks
├── packages.yml             # dbt_utils, dbt_expectations, codegen
├── profiles.yml             # NOT here — lives in ~/.dbt/ (see setup below)
├── macros/
│   ├── generate_schema_name.sql      # dev/ci/prod schema isolation
│   └── test_scd2_no_date_overlap.sql # custom SCD2 integrity test
├── models/
│   ├── bronze/              # _sources_*.yml only (Bronze is loaded by notebook)
│   ├── silver/
│   │   ├── staging/         # 1:1 cleaned views over sources
│   │   └── intermediate/    # joins & enrichment
│   └── gold/
│       ├── dimensions/      # 7 dims (Type 1 + SCD2)
│       ├── facts/           # fct_sales_detail
│       └── marts/           # mart_sales_summary
├── snapshots/               # SCD2 snapshots for Product/Employee/SalesTerritory
├── tests/                   # singular (cross-model) tests
├── notebooks/
│   ├── bronze_bootstrap.ipynb   # downloads CSVs → lands Bronze Delta tables
│   ├── run_dbt.ipynb            # runs `dbt build` from a Databricks Job
│   └── scd_data_generator.ipynb # mutates source rows to exercise SCD2
```

---

## Prerequisites

- A **Databricks Free Edition** account — sign up at <https://www.databricks.com/learn/free-edition>. You get a serverless SQL warehouse and Unity Catalog at no cost.
- **Python 3.9 – 3.12** (3.11 recommended).
- **Git**.
- A terminal: **PowerShell** on Windows, or **bash/zsh** on macOS/Linux.

---

## Getting started

The steps below take you from a clean machine to a fully built, tested
warehouse. Commands are shown for **Windows PowerShell** and **macOS/Linux
bash**.

### 1. Set up Databricks and collect the required connection details

In your Databricks Free Edition workspace:

1. **Create a SQL Warehouse** (or use the default serverless warehouse).
   Open the warehouse → **Connection details** and record:

   * **Server hostname** — e.g. `dbc-xxxxxxxx-xxxx.cloud.databricks.com`
     *(Do not include `https://` or a trailing `/`.)*

   * **HTTP path** — e.g. `/sql/1.0/warehouses/abc123def456`

2. **Create a Personal Access Token (PAT):**
   Go to **Avatar → Settings → Developer → Access tokens → Generate new token**.
   Copy the `dapi...` value immediately — it is only displayed once.

You now have the three values dbt needs to connect to Databricks:

* `host`
* `http_path`
* `token`

### 2. Clone the repo

```bash
git clone https://github.com/hjtc365/adventureworks-databricks-medallion-dbt.git
cd adventureworks-databricks-medallion-dbt
```

### 3. Install Python and verify it works

dbt Core is a Python application, so Python needs to be installed before you
create the project's virtual environment. Use **Python 3.11** if you have the
choice; it is the safest version for compatibility across dbt and Databricks
tooling.

First, check whether Python is already installed:

**Windows PowerShell**

```powershell
py --list
python --version
```

**macOS / Linux**

```bash
python3 --version
```

You want to see a Python version in the **3.9 - 3.12** range. If you already
have **3.11.x**, keep it and move on.

If Python is not installed:

**Windows**

- Install it from <https://www.python.org/downloads/>.
- During setup, check **Add Python to PATH**.
- After install, open a new PowerShell window and re-run `python --version`.

**macOS**

```bash
brew install python@3.11
python3.11 --version
```

**Ubuntu / Debian**

```bash
sudo apt update
sudo apt install python3.11 python3.11-venv
python3.11 --version
```

If the version command works, Python is installed correctly and you can create
the project venv.

### 4. Create and activate a Python virtual environment

A virtual environment keeps this project's packages isolated from your system
Python.

**Windows PowerShell**

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
```

> If PowerShell blocks the activate script with *"running scripts is disabled
> on this system"*, relax the policy for the current session only:
> `Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`, then
> re-run the activate command.

**macOS / Linux**

```bash
python3.11 -m venv .venv
source .venv/bin/activate
```

Your prompt should now show the `(.venv)` prefix. Re-activate every time you
open a new terminal.

### 5. Install dbt

Install **only** the adapter — it pulls in the matching `dbt-core`
automatically. Never pin `dbt-core` separately.

```bash
python -m pip install --upgrade pip
pip install "dbt-databricks==1.12.*"
```

Verify:

```bash
dbt --version
```

### 6. Install dbt package dependencies

```bash
dbt deps
```

This downloads `dbt_utils`, `dbt_expectations`, and `codegen` into
`dbt_packages/` (git-ignored).

### 7. Configure `profiles.yml`

`profiles.yml` describes **how your machine connects to Databricks**. It lives
in your home directory, **not** in the repo, because it's machine-specific and
references a secret token.

Create the `.dbt` folder:

**Windows PowerShell**

```powershell
mkdir $env:USERPROFILE\.dbt -ErrorAction SilentlyContinue
```

**macOS / Linux**

```bash
mkdir -p ~/.dbt
```

Then create `~/.dbt/profiles.yml` (Windows: `%USERPROFILE%\.dbt\profiles.yml`)
with this content. Secrets are read from environment variables, not hard-coded
— so the file itself is safe to keep and share.

```yaml
adventureworks:
  target: dev
  outputs:
    dev:
      type: databricks
      catalog: adventureworks_dev
      schema: default
      host: "{{ env_var('DBT_DBX_HOST') }}"
      http_path: "{{ env_var('DBT_DBX_HTTP_PATH') }}"
      token: "{{ env_var('DBT_DBX_TOKEN') }}"
      threads: 4
    prod:
      type: databricks
      catalog: adventureworks_prod
      schema: default
      host: "{{ env_var('DBT_DBX_HOST') }}"
      http_path: "{{ env_var('DBT_DBX_HTTP_PATH_PROD') }}"
      token: "{{ env_var('DBT_DBX_TOKEN') }}"
      threads: 8
```

> The profile name `adventureworks` must match `profile: 'adventureworks'` in
> `dbt_project.yml`. The only difference between `dev` and `prod` is the
> **catalog** — same warehouse, different Unity Catalog catalog, so dev
> experiments never touch production data.

### 8. Set environment variables

dbt reads your Databricks credentials and your developer name from environment
variables at runtime. `DBT_USER` is consumed by the `generate_schema_name`
macro to prefix your dev schemas (e.g. `alice_silver`) so multiple developers
never collide in the shared dev catalog.

**Windows PowerShell — current session**

```powershell
$env:DBT_DBX_HOST           = "dbc-xxxxxxxx-xxxx.cloud.databricks.com"
$env:DBT_DBX_HTTP_PATH      = "/sql/1.0/warehouses/abc123def456"
$env:DBT_DBX_HTTP_PATH_PROD = "/sql/1.0/warehouses/abc123def456"
$env:DBT_DBX_TOKEN          = "dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$env:DBT_USER               = "alice"
```

To persist them across PowerShell sessions, use
`[Environment]::SetEnvironmentVariable`:

```powershell
[Environment]::SetEnvironmentVariable('DBT_DBX_HOST', 'dbc-xxxxxxxx-xxxx.cloud.databricks.com', 'User')
[Environment]::SetEnvironmentVariable('DBT_DBX_HTTP_PATH', '/sql/1.0/warehouses/abc123def456', 'User')
[Environment]::SetEnvironmentVariable('DBT_DBX_HTTP_PATH_PROD', '/sql/1.0/warehouses/abc123def456', 'User')
[Environment]::SetEnvironmentVariable('DBT_DBX_TOKEN', 'dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', 'User')
[Environment]::SetEnvironmentVariable('DBT_USER', 'alice', 'User')
```

**macOS / Linux — current session**

```bash
export DBT_DBX_HOST="dbc-xxxxxxxx-xxxx.cloud.databricks.com"
export DBT_DBX_HTTP_PATH="/sql/1.0/warehouses/abc123def456"
export DBT_DBX_HTTP_PATH_PROD="/sql/1.0/warehouses/abc123def456"
export DBT_DBX_TOKEN="dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export DBT_USER="alice"
```

To persist, add those `export` lines to `~/.bashrc` or `~/.zshrc` and reload
the shell.

> **Never commit your token.** If a PAT is ever exposed, rotate it immediately
> in Databricks — git history retains old values forever.

### 9. Verify the connection

```bash
dbt debug
```

You want `All checks passed!`. If you see *"Env var required but not
provided"*, your environment variables aren't set in the current shell. If you
see *"Could not find profile"*, check the profile name in `profiles.yml`.

### 10. Load the Bronze layer (one-time)

dbt does **not** own ingestion — Bronze is loaded by a notebook. Import
`notebooks/bronze_bootstrap.ipynb` into your Databricks workspace and run it.
It will:

1. Create the catalog, the `bronze` schema, and a `landing` volume.
2. Download the AdventureWorks CSV exports and land them as **external Delta
   tables** (all columns as `STRING` — typing happens in Silver).

Set the notebook's `catalog` widget to `adventureworks_dev` for your dev build
(and re-run with `adventureworks_prod` if you want a prod catalog too).

> Optional: `notebooks/scd_data_generator.ipynb` mutates a few source rows so
> you can watch SCD2 snapshots capture history on subsequent runs.

### 11. Build and test the warehouse

```bash
dbt build
```

`dbt build` runs every model **and** its tests in dependency order, stopping a
branch as soon as an upstream test fails. On success you'll see all Silver and
Gold models materialise into your `<DBT_USER>_silver` / `<DBT_USER>_gold`
schemas, followed by ~558 passing tests.

Useful variations:

```bash
dbt build --select gold                 # just the Gold layer + its tests
dbt build --select +fct_sales_detail    # the fact and everything it depends on
dbt test                                # run the test suite only
dbt build --target prod                 # build into the prod catalog
```

---

## Multi-environment schema isolation

The custom `macros/generate_schema_name.sql` routes every model into an
environment-specific schema so `dev`, `ci`, and `prod` never collide:

| Target | Schema pattern | Example |
|--------|----------------|---------|
| `dev` | `<DBT_USER>_<layer>` | `alice_silver`, `alice_gold` |
| `ci` | `pr_<PR_NUMBER>_<layer>` | `pr_42_silver` |
| `prod` | `<layer>` (no prefix) | `silver`, `gold` |

This is what lets a whole team share one `adventureworks_dev` catalog, and what
makes pull-request CI builds disposable (drop `pr_42_*` after merge).

---

## Automating builds with Databricks Jobs

The two notebooks (`bronze_bootstrap` and `run_dbt`) can be wired together as
Databricks Jobs so that a **single click loads both `dev` and `prod`** end to
end. The setup uses **four jobs** arranged in a layered hierarchy: two *leaf*
jobs that each wrap one notebook, a *pipeline* job that chains them for one
environment, and an *orchestrator* job that fans the pipeline out across every
environment.

```mermaid
flowchart TD
    O["environment-orchestrator<br/>for_each environments = [dev, prod]"]
    P["environment-pipeline<br/>param: environment"]
    B["bronze-bootstrap<br/>param: catalog"]
    R["run-dbt<br/>param: target"]

    O -->|environment = dev| P
    O -->|environment = prod| P
    P -->|catalog = adventureworks_#123;#123;environment#125;#125;| B
    B --> R
    R -.->|target = #123;#123;environment#125;#125;| R
```

| Job | Role | Runs | Key parameter |
|-----|------|------|---------------|
| **bronze-bootstrap** | leaf | `notebooks/bronze_bootstrap` | `catalog` (default `adventureworks_dev`) |
| **run-dbt** | leaf | `notebooks/run_dbt` | `target` (default `dev`) |
| **environment-pipeline** | chains the two leaves for one env | bronze-bootstrap → run-dbt | `environment` (default `dev`) |
| **environment-orchestrator** | fans the pipeline across all envs | environment-pipeline per env | `environments` (default `["dev", "prod"]`) |

### How the parameters flow

1. **environment-orchestrator** holds a JSON array parameter `environments`
   (default `["dev", "prod"]`) and uses a **`for_each` task** to run
   **environment-pipeline** once per element, passing each value through as
   `environment = {{input}}`.
2. **environment-pipeline** receives a single `environment` and runs the two
   leaf jobs in order:
   - **bronze-bootstrap** with `catalog = adventureworks_{{environment}}`
   - **run-dbt** with `target = {{environment}}` (only after bronze-bootstrap
     succeeds — see `depends_on`)
3. The leaf jobs hand those values straight to the notebook widgets
   (`catalog` and `target`), so the same notebooks serve every environment.

This is why building both catalogs is one action: run
**environment-orchestrator** and it loops `dev` then `prod`, each time
bootstrapping Bronze into `adventureworks_<env>` and then running
`dbt build --target <env>`.

> For CI/CD pipelines and repeatable deployments across workspaces, these four
> jobs can also be defined as a **Databricks Asset Bundle** and deployed with
> the Databricks CLI instead of the Workflows UI.

### Step 1 — Create the `aw` Databricks Secret scope

The `run_dbt` notebook reads five values from a Databricks Secret scope named
`aw`. The scope must exist **before** any of the jobs run, otherwise the
`run-dbt` task fails with `SecretNotFound`.

You need the **v0.205+ Databricks CLI** for this (the new Go-based CLI, not
the legacy `pip install databricks-cli` package). Install once:

```bash
# Windows
winget install Databricks.DatabricksCLI

# macOS
brew tap databricks/tap && brew install databricks

# Linux / other
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
```

Authenticate against your workspace (opens a browser):

```bash
databricks auth login --host https://dbc-xxxxxxxx-xxxx.cloud.databricks.com
```

Create the scope and populate the five keys. Values are sent over TLS and
never echoed back to the terminal.

```bash
databricks secrets create-scope aw

databricks secrets put-secret aw host       --string-value "dbc-xxxxxxxx-xxxx.cloud.databricks.com"
databricks secrets put-secret aw http_path  --string-value "/sql/1.0/warehouses/abc123def456"
databricks secrets put-secret aw dbt_token  --string-value "dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
databricks secrets put-secret aw dbt_user   --string-value "<your-dbt-user-prefix>"
```

Verify:

```bash
databricks secrets list-scopes
databricks secrets list-secrets aw   # should list: host, http_path, dbt_token, dbt_user
```

> `host` is the workspace hostname **without** `https://` and **without** a
> trailing `/`. `http_path` is the SQL Warehouse's HTTP path from
> **Connection details**. `dbt_token` is the same Databricks PAT you put in
> `~/.dbt/profiles.yml`. `dbt_user` is the value that the
> `generate_schema_name` macro uses to prefix dev schemas (e.g. `alice`
> produces `alice_silver`, `alice_gold`).

### Step 2 — Clone the repo as a Databricks Git folder

Databricks now recommends creating Git folders from your **home folder** rather
than under the legacy `/Repos` path:

1. In the workspace UI, navigate to **Workspace → Home**.
2. Click **Create → Git folder** (top-right button).
3. Paste the HTTPS URL of your fork:
   `https://github.com/<your-github-username>/adventureworks-databricks-medallion-dbt.git`
4. Leave the folder name as-is and click **Create Git folder**.

This clones the repo under
`/Workspace/Users/<you>@example.com/adventureworks-databricks-medallion-dbt`,
which is the path used in the `notebook_path` values below — adjust them if
you chose a different location.

> The legacy path **Workspace → Repos → Add repo** still works if you prefer
> it; your folder will be visible under `/Workspace/Repos/<you>@example.com/`
> instead.

### Step 3 — Build the four jobs in the Workflows UI

Create the jobs **bottom-up** so each parent can pick its children's job IDs
from the dropdown:

1. **bronze-bootstrap** — new Job → single **Notebook** task pointing at
   `notebooks/bronze_bootstrap`. Add a job parameter `catalog` =
   `adventureworks_dev`.
2. **run-dbt** — new Job → single **Notebook** task pointing at
   `notebooks/run_dbt`. Add a job parameter `target` = `dev`. Use a bare
   serverless environment — **do not** add `dbt-databricks` as a job
   dependency. The notebook installs its own pinned version via
   `%pip install "dbt-databricks==1.12.*"` and restarts Python, so declaring it
   at the job level is redundant and risks a version mismatch.
3. **environment-pipeline** — new Job with two **Run Job** tasks:
   - `bronze-bootstrap` → run the bronze-bootstrap job with
     `catalog = adventureworks_{{job.parameters.environment}}`.
   - `run-dbt` → **depends on** `bronze-bootstrap`, runs the run-dbt job with
     `target = {{job.parameters.environment}}`.
   - Add a job parameter `environment` = `dev`.
4. **environment-orchestrator** — new Job with one **For each** task whose
   input is `{{job.parameters.environments}}`; the nested task is a **Run Job**
   on environment-pipeline with `environment = {{input}}`. Add a job parameter
   `environments` = `["dev", "prod"]`.

### Step 4 — Run

Run **environment-orchestrator** to load `dev` and `prod` in one go, or run
**environment-pipeline** with `environment=dev` (or `prod`) to load a single
environment.

---

## Browse the lineage docs

```bash
dbt docs generate
dbt docs serve
```

This opens an interactive site at `http://localhost:8080` with the full model
lineage graph, per-model compiled SQL, column-level documentation, and test
coverage. With `persist_docs` enabled in `dbt_project.yml`, the same column
descriptions are pushed into Unity Catalog as `COMMENT`s.

---

## License

MIT
