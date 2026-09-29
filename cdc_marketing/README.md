# CDC Marketing Analytics with dbt + Databricks

> From raw Facebook advertising tables to tested, documented, analytics-ready facts and dimensions.

Welcome to the **CDC Marketing Analytics** project! This repository began as a fresh dbt starter project and grew into a practical analytics engineering pipeline built with **dbt Core**, **Databricks**, **Jinja**, **YAML**, **uv**, and **Elementary**.

If you are new to data engineering, do not worry: this README explains what we built, why we built it, how the pieces connect, and how to run the project yourself.

---

## The Big Idea

Marketing platforms produce useful but messy operational data. Account details, campaigns, ad groups, ads, and daily performance statistics arrive in separate tables. Analysts should not need to repeatedly clean, cast, deduplicate, and join those tables before answering questions.

This project turns that raw data into a trustworthy analytics layer:

```text
Raw Facebook Ads data
        |
        v
Sources: declare where the data lives
        |
        v
Staging: clean names and data types
        |
        +------------------------------+
        |                              |
        v                              v
Intermediate: join and deduplicate     Direct daily statistics
        |                              |
        v                              v
Dimension: ad details              Fact: daily ad performance
        \                              /
         \                            /
          +------ Analytics-ready ----+
```

In plain English:

- The **dimension table** answers: *What is this ad, and which account, campaign, and ad group does it belong to?*
- The **fact table** answers: *How much did this ad spend, and how many impressions and clicks did it receive on a given day?*
- dbt's tests answer: *Can we trust the result?*
- dbt Docs and Elementary answer: *Can we understand and monitor the result?*

---

## Our Journey: What We Learned and Achieved

### 1. Built the analytics engineering foundation

We learned how analytics engineering fits between data engineering and analytics:

- Traditional **ETL** transforms data before loading it.
- Modern cloud platforms commonly use **ELT**: extract, load, and then transform inside the warehouse.
- dbt manages the transformation stage with version-controlled SQL, dependency management, testing, and documentation.
- Databricks provides the compute and storage platform where the transformations run.

### 2. Created a reproducible local development environment

The project uses:

- **Python 3.11 or newer**
- **uv** for fast dependency and virtual-environment management
- **dbt-databricks** as the Databricks adapter
- A lock file for repeatable dependency installation
- Environment variables so credentials do not need to be written into SQL

### 3. Connected dbt Core to Databricks

We configured multiple dbt targets in `profiles.yml`:

| Target | Intended use | Authentication |
|---|---|---|
| `dev` | Local development and learning | Databricks personal access token |
| `ci` | Automated validation | OAuth service principal |
| `staging` | Pre-production deployment | OAuth service principal |
| `production` | Production deployment | OAuth service principal |

The active target can be selected with the `DBT_TARGET` environment variable. This keeps environment selection outside the SQL models.

### 4. Declared and documented raw Facebook sources

The project declares five source tables in `bronze_production.cdc_staging`:

- `accounts`
- `campaigns`
- `adgroups`
- `ads`
- `ads_stats`

The source configuration also includes:

- Descriptions
- Ownership metadata
- Event-time columns
- A freshness warning after two days

Using `{{ source(...) }}` instead of hardcoded table names gives dbt enough information to build lineage, check freshness, and detect missing dependencies.

### 5. Built a layered transformation pipeline

The project follows a staging → intermediate → marts pattern:

#### Staging layer

Each staging model stays close to one raw source and performs lightweight cleanup:

- Casts identifiers to strings
- Converts timestamps and dates into the correct types
- Converts spend, clicks, and impressions into numeric types
- Gives downstream models a predictable interface

#### Intermediate layer

`int_facebook_ads_details` performs real business logic:

- Selects the latest version of every ad, ad group, campaign, and account
- Uses `QUALIFY ROW_NUMBER()` to deduplicate history records
- Joins the normalized marketing hierarchy
- Adds `Paid Social` as the standard channel
- Records `facebook_ads` as the data source

#### Marts layer

The final consumer-ready models form a simple star schema:

- `dim_facebook_ads_details` contains descriptive ad attributes.
- `fct_facebook_ads_stats_daily` contains daily performance measures.

These marts are shaped for business intelligence tools, analysts, reporting, and future data products.

### 6. Identified the correct data grain

One of the most important modeling lessons was learning to define a table's **grain**, or what makes one row unique.

For daily ad statistics:

```text
ad_id alone                 = not unique
ad_id + ad_date             = one ad's performance on one day
```

The fact table therefore uses the composite grain `(ad_id, ad_date)`.

### 7. Removed unnecessary pipeline complexity

We learned that every dbt layer must earn its place.

An intermediate daily-statistics draft only selected from staging without joining, aggregating, pivoting, or adding business logic. The active fact model now reads directly from `stg_facebook_ads_basic_all_levels`, producing a cleaner DAG and avoiding unnecessary compute.

The dot-prefixed `.int_facebook_ads_stats_daily` files remain as a learning artifact, but dbt does not treat that hidden draft as an active model.

### 8. Added automated data quality checks

The project now checks important assumptions such as:

- IDs that must not be null
- IDs that must be unique
- Composite keys that must be unique
- `channel_name` values that must equal `Paid Social`

It uses built-in dbt tests and `dbt_utils.unique_combination_of_columns`.

### 9. Added packages and observability

The project includes:

- `dbt_utils` for reusable dbt utilities and tests
- `dbt_expectations` for expressive data quality checks
- `elementary` for test monitoring and data observability

Elementary provides a standalone HTML report for reviewing test results, model health, schema changes, and anomalies.

### 10. Generated successful project artifacts

The project has produced:

- A dbt manifest containing the project's models, sources, tests, and lineage
- Source freshness results
- Static dbt documentation and an interactive lineage graph
- An Elementary HTML observability report
- A recorded documentation generation run with **54 successful results**

That means this repository is no longer just a collection of SQL files—it has an executable DAG, quality checks, documentation, and observability.

---

## Architecture and Data Flow

```text
bronze_production.cdc_staging
|
|-- accounts -----> stg_facebook_ads_account_history -----+
|-- campaigns ----> stg_facebook_ads_campaign_history ----|
|-- adgroups -----> stg_facebook_ads_ad_set_history ------+--> int_facebook_ads_details
|-- ads ----------> stg_facebook_ads_ad_history ----------|             |
|                                                                    v
|                                                     dim_facebook_ads_details
|
`-- ads_stats ----> stg_facebook_ads_basic_all_levels
                                 |
                                 v
                    fct_facebook_ads_stats_daily
```

### Star schema

```text
dim_facebook_ads_details             fct_facebook_ads_stats_daily
-----------------------------        --------------------------------
ad_id (primary key)          <------ ad_id (foreign key)
ad_name                              ad_date
ad_group_id                          ad_spend
ad_group_name                        ad_impressions
campaign_id                          ad_clicks
campaign_name
account_id
account_name
channel_name
data_src
```

The dimension has one current descriptive row per ad. The fact can have many rows per ad—normally one row for each date.

---

## Project Structure

```text
cdc_marketing/
|-- analyses/                 Ad hoc SQL that dbt compiles but does not build
|-- macros/                   Reusable Jinja and environment-routing logic
|-- models/
|   |-- staging/
|   |   |-- facebook/        Facebook sources and source-aligned cleanup
|   |   `-- snapchat/        Placeholder for future platform expansion
|   |-- intermediate/
|   |   `-- facebook/        Deduplication and multi-table business joins
|   `-- marts/
|       |-- dim/facebook/    Descriptive analytics dimensions
|       `-- fact/facebook/   Measurable business events
|-- seeds/                    Small static CSV lookup data
|-- snapshots/                Historical tracking for changing records
|-- tests/                    Custom singular data tests
|-- dbt_project.yml           Main dbt project configuration
|-- packages.yml              dbt package dependencies
|-- profiles.yml              Databricks targets and authentication settings
|-- pyproject.toml            Python project and package dependencies
|-- uv.lock                   Reproducible Python dependency lock
`-- .env.template             Example local environment variables
```

Folders containing `.gitkeep` are intentionally ready for future work even when they do not yet contain active project logic.

---

## Model Guide

| Model | Layer | Purpose | Expected grain |
|---|---|---|---|
| `stg_facebook_ads_account_history` | Staging | Cleans Facebook account history | One row per account update |
| `stg_facebook_ads_campaign_history` | Staging | Cleans campaign history | One row per campaign update |
| `stg_facebook_ads_ad_set_history` | Staging | Cleans ad-group history | One row per ad-group update |
| `stg_facebook_ads_ad_history` | Staging | Cleans ad history | One row per ad update |
| `stg_facebook_ads_basic_all_levels` | Staging | Cleans daily spend, impression, and click statistics | One row per ad per date |
| `int_facebook_ads_details` | Intermediate | Deduplicates and joins the latest descriptive records | One row per ad |
| `dim_facebook_ads_details` | Mart dimension | Exposes analytics-ready ad details | One row per ad |
| `fct_facebook_ads_stats_daily` | Mart fact | Exposes daily ad performance | One row per ad per date |

---

## Beginner Setup Guide

### Prerequisites

Install or obtain:

1. Git
2. Python 3.11+
3. [uv](https://docs.astral.sh/uv/)
4. Access to a Databricks workspace
5. A running Databricks SQL warehouse
6. The Databricks host, warehouse HTTP path, catalog, schema, and authentication values

### 1. Open the dbt project

In PowerShell:

```powershell
cd C:\Users\Elijay\Desktop\CDE3BootCamp\cdc_modeling\cdc_marketing
```

If you cloned the repository elsewhere, use your own path.

### 2. Install the locked Python dependencies

```powershell
uv sync
```

### 3. Install the dbt packages

```powershell
uv run dbt deps
```

This downloads the packages declared in `packages.yml` into `dbt_packages/`.

### 4. Set local Databricks environment variables

For the current PowerShell session:

```powershell
$env:DBT_TARGET = "dev"
$env:DEV_SCHEMA = "cdc_staging"
$env:DEV_CATALOG = "bronze_production"
$env:DEV_HTTP_PATH = "/sql/1.0/warehouses/your-warehouse-id"
$env:DATABRICKS_PAT_TOKEN = "your-token"
```

> **Security rule:** never commit real tokens, client secrets, or `.env` files. The repository ignores `.env`; `.env.template` contains placeholders only.

### 5. Test the connection and configuration

```powershell
uv run dbt debug --profiles-dir .
```

`dbt debug` checks the project configuration, profile, authentication, network connection, and Databricks target.

### 6. Compile before you run

```powershell
uv run dbt compile --profiles-dir .
```

Compilation turns Jinja-enabled model files into warehouse-ready SQL without building tables or views. It is a safe way to catch references, YAML problems, and SQL-generation mistakes.

### 7. Build models and run their tests

```powershell
uv run dbt build --profiles-dir .
```

`dbt build` is the most useful all-in-one command because it builds resources in dependency order and runs their tests.

---

## Everyday Command Cheat Sheet

```powershell
# Validate the project and Databricks connection
uv run dbt debug --profiles-dir .

# Download or update packages from packages.yml
uv run dbt deps

# Parse the project without connecting to the warehouse
uv run dbt parse --profiles-dir .

# Compile Jinja and refs into executable SQL
uv run dbt compile --profiles-dir .

# Run models only
uv run dbt run --profiles-dir .

# Run tests only
uv run dbt test --profiles-dir .

# Build models and execute tests in DAG order
uv run dbt build --profiles-dir .

# Check whether Facebook source data is fresh
uv run dbt source freshness --select source:facebook_ads --profiles-dir .

# Build the ad-details model and all upstream dependencies
uv run dbt build --select +int_facebook_ads_details --profiles-dir .

# Build the dimension and everything it depends on
uv run dbt build --select +dim_facebook_ads_details --profiles-dir .

# Generate one portable documentation file
uv run dbt docs generate --static --profiles-dir .

# Remove generated dbt artifacts and downloaded packages
uv run dbt clean

# Generate the Elementary observability report
uv run edr report --days-back 90 --profiles-dir .
```

### Understanding dbt's `+` graph operator

| Selector | Meaning |
|---|---|
| `model_name` | Select only this model |
| `+model_name` | Select this model and all upstream parents |
| `model_name+` | Select this model and all downstream children |
| `+model_name+` | Select the model, its parents, and its children |

This is one of dbt's superpowers: you can work with the lineage graph instead of manually listing every dependency.

---

## How dbt Knows the Build Order

Two Jinja functions create the DAG:

```sql
{{ source('facebook_ads', 'ads') }}
```

`source()` points to raw data declared in a source YAML file.

```sql
{{ ref('stg_facebook_ads_ad_history') }}
```

`ref()` points to another dbt model. It also tells dbt that the referenced model must be built first.

Avoid replacing these functions with hardcoded three-level table names. Hardcoding removes useful lineage and makes environment changes harder.

---

## Data Quality: What We Test and Why

A dbt data test passes when its query returns **zero invalid rows**.

| Test | What it protects |
|---|---|
| `not_null` | Required identifiers are present |
| `unique` | A primary key appears only once |
| `accepted_values` | A category contains only approved values |
| `dbt_utils.unique_combination_of_columns` | A composite grain, such as ad plus date, remains unique |

Example:

```yaml
data_tests:
  - dbt_utils.unique_combination_of_columns:
      combination_of_columns:
        - ad_id
        - ad_date
```

This protects the fact table from duplicate daily statistics.

### Generic and singular tests

- **Generic tests** are reusable checks declared in YAML.
- **Singular tests** are custom SQL queries stored in `tests/`; every returned row represents a failure.

The `tests/` directory is ready for future business-specific checks, such as preventing negative advertising spend.

---

## Dynamic Environments and Custom Macros

The project overrides dbt's database and schema naming behavior with:

- `generate_database_name`
- `generate_schema_name`

These macros let approved targets use explicitly configured catalogs and schemas while retaining dbt's default behavior elsewhere. This is useful when the same project must run safely in development, CI, staging, and production.

The main lesson is simple:

> Keep transformation logic consistent, but inject environment-specific destinations and credentials at runtime.

---

## Documentation and Observability

### dbt Docs

Generate portable documentation:

```powershell
uv run dbt docs generate --static --profiles-dir .
```

The result includes:

- Model and column descriptions
- Source definitions
- Tests
- Compiled SQL
- An interactive DAG

Good YAML descriptions help humans, BI tools, and AI assistants such as Databricks Genie understand the intended meaning of the data.

### Elementary

Generate the Elementary report:

```powershell
uv run edr report --days-back 90 --profiles-dir .
```

The report helps inspect:

- dbt test results
- Model run health
- Data freshness
- Schema changes
- Anomalies and observability history

In a production environment, this report should be published to secure internal storage and connected to an alerting workflow.

---

## Lessons from Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| `dbt` is not recognized | dbt is installed only inside the uv environment | Prefix commands with `uv run` |
| Profile not found | dbt defaults to the user `.dbt` folder | Add `--profiles-dir .` |
| Authentication failure | Token, host, or HTTP path is missing or incorrect | Recheck the current environment variables and SQL warehouse |
| Source not found | `source()` names do not match `sources.yml` exactly | Align the source and table names |
| Model not found | `ref()` does not match an active model filename | Correct the reference or restore the dependency |
| YAML parsing error | Indentation, missing colons, or unquoted special values | Validate spacing and quote values such as `@cde_engineer` |
| Package test not found | Packages have not been installed | Run `uv run dbt deps` |
| Noisy documentation graph | Package and Elementary nodes are visible | Filter the dbt Docs graph with `source:facebook_ads+` |
| Duplicate fact rows | The declared grain is incomplete | Test the combination of `ad_id` and `ad_date` |

Recommended diagnosis order:

1. Confirm you are in the dbt project directory.
2. Run `uv sync`.
3. Run `uv run dbt deps`.
4. Confirm the environment variables are set.
5. Run `uv run dbt debug --profiles-dir .`.
6. Run `uv run dbt compile --profiles-dir .`.
7. Build a small selected lineage before rebuilding everything.

---

## Important Concepts for Beginners

| Term | Beginner-friendly meaning |
|---|---|
| **Model** | A SQL `SELECT` statement that dbt turns into a view or table |
| **Source** | Raw data that already exists before dbt runs |
| **DAG** | A dependency map showing what must run before what |
| **Grain** | The exact real-world meaning of one row |
| **Dimension** | Descriptive data, such as an ad or campaign name |
| **Fact** | Measurable events, such as spend, clicks, or impressions |
| **Staging** | The first cleanup layer over raw data |
| **Intermediate** | Reusable joins or business transformations |
| **Mart** | A final dataset designed for analytics consumers |
| **Materialization** | How dbt stores a model: view, table, incremental, or ephemeral |
| **Macro** | Reusable Jinja logic that generates SQL or changes dbt behavior |
| **Freshness** | A check that source data has arrived recently enough |
| **Observability** | Monitoring whether data pipelines remain healthy and trustworthy |

---

## Advanced Topics We Learned Next

The course also introduced techniques that are valuable as data volume grows. These are **learning goals and next-stage improvements**, not all active configurations in the current models:

- Incremental models that process only new or changed data
- `merge`, `append`, and `delete+insert` incremental strategies
- Microbatch processing for large event-time datasets
- Lookback windows for late-arriving advertising events
- `TRY_CAST` for safely handling malformed raw values
- Model contracts for stronger column guarantees
- Snapshots for Slowly Changing Dimension Type 2 history
- Cross-platform marketing models for Facebook, Snapchat, and future sources
- CI/CD deployments using OAuth service principals

### Why microbatching matters

Rebuilding years of advertising history every day is expensive. A future microbatch fact model could process daily slices using `ad_date`, rerun a short lookback period, and efficiently capture late-arriving records.

Optimization should follow correctness: first establish the grain and tests, then optimize the workload.

---

## Suggested Next Milestones

- [ ] Add relationship tests between the fact and dimension on `ad_id`
- [ ] Add stronger column descriptions for every final mart
- [ ] Add accepted-value and non-negative metric checks
- [ ] Decide whether malformed metrics should use `TRY_CAST`
- [ ] Add model contracts after schemas stabilize
- [ ] Configure and test CI, staging, and production destinations
- [ ] Add secure automated dbt and Elementary reporting
- [ ] Introduce incremental or microbatch materialization when data volume justifies it
- [ ] Build the Snapchat source and staging layer
- [ ] Add more advertising platforms and create conformed cross-platform marts
- [ ] Connect the marts to Power BI, Tableau, or Databricks SQL dashboards

---

## Resources

### Existing dbt community resources

- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices

### More resources for this project

- [dbt quickstart guides](https://docs.getdbt.com/guides)
- [dbt command reference](https://docs.getdbt.com/reference/dbt-commands)
- [dbt model selection syntax](https://docs.getdbt.com/reference/node-selection/syntax)
- [dbt data tests](https://docs.getdbt.com/docs/build/data-tests)
- [dbt sources and freshness](https://docs.getdbt.com/docs/build/sources)
- [dbt project documentation](https://docs.getdbt.com/docs/collaborate/documentation)
- [dbt Jinja and macros](https://docs.getdbt.com/docs/build/jinja-macros)
- [dbt incremental models](https://docs.getdbt.com/docs/build/incremental-models)
- [dbt microbatch strategy](https://docs.getdbt.com/docs/build/incremental-microbatch)
- [dbt snapshots](https://docs.getdbt.com/docs/build/snapshots)
- [dbt-utils package](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/)
- [dbt-expectations package](https://hub.getdbt.com/metaplane/dbt_expectations/latest/)
- [Elementary documentation](https://docs.elementary-data.com/)
- [Databricks documentation](https://docs.databricks.com/)
- [dbt and Databricks setup](https://docs.getdbt.com/docs/core/connect-data-platform/databricks-setup)
- [Databricks Unity Catalog](https://docs.databricks.com/aws/en/data-governance/unity-catalog/)
- [uv documentation](https://docs.astral.sh/uv/)
- [Kimball dimensional modeling techniques](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/)

---

## Final Takeaway

This project demonstrates an end-to-end analytics engineering mindset:

1. Understand the raw data.
2. Declare trustworthy sources.
3. Clean data in staging.
4. Add business logic only where it creates value.
5. Define the grain before building facts and dimensions.
6. Test assumptions automatically.
7. Document the DAG.
8. Monitor data quality.
9. Optimize only after correctness is established.

We did not merely write SQL—we built a maintainable path from raw marketing data to reliable business insight. 🚀
