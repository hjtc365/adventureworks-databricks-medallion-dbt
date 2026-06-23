# Deploying the jobs as a Databricks Asset Bundle

A **Databricks Asset Bundle (DAB)** declares the project's four jobs in code and
deploys them to a workspace with the Databricks CLI — no clicking through the
Workflows UI, and everything is version-controlled and reproducible across
workspaces.

```text
environment-orchestrator
└── environment-pipeline   (one per environment in ["dev", "prod"])
    ├── bronze-bootstrap   (param: catalog = adventureworks_<env>)
    └── run-dbt            (param: target  = <env>)
```

Running **environment-orchestrator** once builds **both** `adventureworks_dev`
and `adventureworks_prod` end to end.

> Prefer to wire the jobs up by hand? The Workflows UI walkthrough is in
> **[Automating builds with Databricks Jobs](databricks-jobs-ui.md)**. The two
> approaches produce the same four jobs — pick one.

---

## How the bundle is laid out

The bundle is **already defined in this repo** — there is nothing to author.

| File | Purpose |
|------|---------|
| [`databricks.yml`](../databricks.yml) | Bundle descriptor at the repo root. Names the bundle, declares the `dev`/`prod` targets, and globs in every `resources/*.job.yml`. **Must live at the repo root** — the CLI looks for it there. |
| [`resources/bronze_bootstrap.job.yml`](../resources/bronze_bootstrap.job.yml) | Leaf job wrapping `notebooks/bronze_bootstrap`. Parameter: `catalog`. |
| [`resources/run_dbt.job.yml`](../resources/run_dbt.job.yml) | Leaf job wrapping `notebooks/run_dbt`. Parameter: `target`. |
| [`resources/environment_pipeline.job.yml`](../resources/environment_pipeline.job.yml) | Chains the two leaves for one environment. Parameter: `environment`. |
| [`resources/environment_orchestrator.job.yml`](../resources/environment_orchestrator.job.yml) | `for_each` over `environments` (JSON array). Parameter: `environments`. |

The parent jobs reference their children with `${resources.jobs.<name>.id}`,
which the bundle resolves to real job IDs at deploy time — so there are **no
numeric job IDs** to hard-code anywhere. The notebook paths use
`${workspace.current_user.userName}`, so the bundle resolves them to *your*
home folder automatically — no per-user editing of the job files.

---

## 1. Install the Databricks CLI

The Asset Bundle workflow requires the **v0.205+** CLI (the rewrite in Go),
**not** the legacy `pip install databricks-cli` package.

**Windows (PowerShell)**

```powershell
winget install Databricks.DatabricksCLI
```

**macOS (Homebrew)**

```bash
brew tap databricks/tap
brew install databricks
```

**Linux / other (one-liner installer)**

```bash
curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
```

Verify the version (must be `0.205.0` or higher):

```bash
databricks --version
```

> If `databricks --version` prints something like `0.18.0`, you have the
> legacy Python CLI on your PATH. Uninstall it (`pip uninstall databricks-cli`)
> and reinstall using one of the methods above — the legacy CLI has no
> `bundle` subcommand.

---

## 2. Authenticate the CLI

Pick **one** of the two methods below. Both let `databricks bundle …` reach
your workspace.

### Option A — `.databrickscfg` profile (host + token)

Use this if you already have a Personal Access Token and prefer a plain config
file. The bundle's two targets each declare a **`profile:`** mapping in
[`databricks.yml`](../databricks.yml) (`targets.dev.workspace.profile: dev` and
`targets.prod.workspace.profile: prod`), so the CLI loads the matching named
profile from `~/.databrickscfg` (Windows: `%USERPROFILE%\.databrickscfg`). The
workspace **URL lives only in this local file** — it is never committed to the
repo.

Create one profile per target, named to match the `profile:` values
(`dev` and `prod`):

```ini
[dev]
host  = https://dbc-xxxxxxxx-xxxx.cloud.databricks.com
token = dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

[prod]
host  = https://dbc-yyyyyyyy-yyyy.cloud.databricks.com
token = dapiYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
```

- The profile **names must match** the `profile:` values in `databricks.yml` —
  `[dev]` ↔ `targets.dev`, `[prod]` ↔ `targets.prod`. That name match is what
  binds each target to a workspace, so `deploy -t prod` always reaches the prod
  workspace.
- Point each profile's `host` at the workspace you want that target to deploy
  to (same workspace for both is fine if you only have one).
- You can override the target's profile with `-p <profile>` for a one-off, e.g.
  `databricks bundle deploy -t prod -p some-other-profile`.

> The Databricks CLI may also write a `[DEFAULT]` section (used only as a
> fallback when no profile is selected) and a `[__settings__]` section with
> `default_profile = dev` (the profile bare `databricks …` commands use). Both
> are harmless — leave them as the CLI generated them.

Generate each token in its workspace via **Avatar → Settings → Developer →
Access tokens → Generate new token**. Confirm the CLI can authenticate:

```bash
databricks current-user me -p dev       # uses the [dev] profile
databricks current-user me -p prod      # uses the [prod] profile
```

> **Never commit `.databrickscfg`** — it lives in your home directory, outside
> the repo, and holds live tokens. Rotate a token in Databricks if it ever
> leaks.

### Option B — OAuth user-to-machine (U2M)

The CLI opens a browser, you log in once, and a short-lived token is cached
locally — no PAT to manage. Pass `--profile` so the cached profile is named to
match the bundle's `profile:` mapping (`dev` / `prod`):

```bash
databricks auth login --host https://dbc-xxxxxxxx-xxxx.cloud.databricks.com --profile dev
databricks auth login --host https://dbc-yyyyyyyy-yyyy.cloud.databricks.com --profile prod
```

Verify:

```bash
databricks auth profiles
databricks current-user me -p dev
```

---

## 3. Create the `aw` secret scope (required by `run_dbt`)

The `run_dbt` notebook reads four secrets from a scope named `aw`. They must
exist **before** the bundle runs, otherwise the dbt task fails with a
`SecretNotFound` error.

From the same terminal where you authenticated the CLI:

```bash
# 1. Create the scope (Databricks-backed; safe to re-run).
databricks secrets create-scope aw

# 2. Populate it. Values are sent to Databricks over TLS and never echoed
#    back. Replace the right-hand strings with your real values.
databricks secrets put-secret aw host       --string-value "dbc-xxxxxxxx-xxxx.cloud.databricks.com"
databricks secrets put-secret aw http_path  --string-value "/sql/1.0/warehouses/abc123def456"
databricks secrets put-secret aw dbt_token  --string-value "dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
databricks secrets put-secret aw dbt_user   --string-value "<your-dbt-user-prefix>"
```

Confirm:

```bash
databricks secrets list-scopes
databricks secrets list-secrets aw
```

| Secret key | Value to supply |
|------------|-----------------|
| `host` | Workspace hostname **without** `https://` and **without** a trailing `/` |
| `http_path` | SQL Warehouse **HTTP path** from **Connection details** |
| `dbt_token` | The same PAT you use for local dbt runs (`dapi…`) |
| `dbt_user` | The value the `generate_schema_name` macro uses to prefix dev schemas (e.g. `alice` → `alice_silver`, `alice_gold`) |

---

## 4. Point the bundle at your workspace

There is **nothing to edit in `databricks.yml`** — its targets reference
workspaces by profile name (`profile: dev` / `profile: prod`), not by URL. The
actual workspace URLs live only in your local `~/.databrickscfg` (Step 2), which
keeps them out of source control.

So "pointing the bundle" just means making sure your `[dev]` and `[prod]`
profiles exist and target the workspaces you intend. Use two different
workspaces to keep dev and prod fully separate, or point both profiles at the
same workspace if you only have one:

```ini
[dev]
host  = https://dbc-xxxxxxxx-xxxx.cloud.databricks.com
token = dapiXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

[prod]
host  = https://dbc-yyyyyyyy-yyyy.cloud.databricks.com
token = dapiYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
```

> Prefer to keep workspace URLs *in* the repo? Replace each target's `profile:`
> with a `host:` line in `databricks.yml` instead — both are valid. This project
> uses `profile:` so the URLs stay local.

---

## 5. Validate, deploy, run

Run all commands from the **repo root** (where `databricks.yml` lives).

```bash
# (a) Lint the bundle and check that every reference resolves.
databricks bundle validate

# (b) Deploy to the default target (dev). Use -t prod to deploy to prod.
databricks bundle deploy

# (c) Trigger the orchestrator. With default parameters it fans out to
#     ["dev", "prod"] and loads both environments end to end.
databricks bundle run environment_orchestrator
```

To load just one environment, run the pipeline directly:

```bash
databricks bundle run environment_pipeline -- --params environment=dev
```

Add `-p <profile>` to any command to select a specific `.databrickscfg`
profile, or `-t prod` to target the prod workspace.

To tear everything down:

```bash
databricks bundle destroy
```

---

## How `mode: development` and `mode: production` differ

In [`databricks.yml`](../databricks.yml):

| Target | `mode`        | Effect on deployed jobs |
|--------|---------------|-------------------------|
| `dev`  | `development` | Job names are prefixed with `[dev <user>]`, schedules and triggers are paused, and resources are tagged with your username — so multiple developers can deploy in parallel without colliding with each other or with production. |
| `prod` | `production`  | Jobs are deployed verbatim with their declared names, schedules, and triggers active. |

This is the standard Databricks pattern and is why `dev` is set as
`default: true` — running `databricks bundle deploy` without `-t prod` is
always the safe local action.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Error: unknown command "bundle"` | Legacy Python CLI on PATH. | Install the v0.205+ CLI (Step 1). |
| `Error: cannot resolve host` / wrong workspace gets the deploy | The named profile is missing from `~/.databrickscfg`, or points at the wrong workspace. | Create/fix the `[dev]`/`[prod]` profile (Step 2) so its name matches the target's `profile:` and its `host` is correct. |
| `Error: failed to compute file digest ... notebook not found` | Notebook missing from the workspace. | Clone the repo as a Git folder first; the bundle uploads the notebooks on deploy, but the dbt task still needs the repo present at the resolved path. |
| `SecretNotFound: Secret does not exist with scope: aw and key: host` | `aw` scope/keys missing. | Re-run Step 3 — all four keys must be set. |
| `dbt deps` fails with `package-lock.yml ... is not valid` | Lock file generated by a newer dbt version. | Delete `package-lock.yml` locally and re-run; it regenerates against the version pinned in the `run_dbt` notebook. |
