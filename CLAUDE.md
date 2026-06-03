# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

R-based pipeline for analyzing flow cytometry data from the Cytek Aurora spectral flow cytometer. The pipeline uses `flowCore` and `ggcyto` as its primary packages. This pipeline is being developed with reproducibility as a north star — every convention and decision documented here exists for that reason.

## Commands

Render a single R Markdown script:

```r
rmarkdown::render("scripts/00_data_structures.rmd")
```

Or from the terminal:

```bash
Rscript -e 'rmarkdown::render("scripts/00_data_structures.rmd")'
```

## Project Directory Structure

```
project/
├── data/
│   ├── raw/          # Unprocessed FCS files directly from instrument — never modified
│   ├── unmixed/      # Unmixed FCS files exported from SpectroFlo — starting point for all R analysis
├── metadata/
│   ├── experiment_metadata.csv
│   └── sample_metadata.csv
├── scripts/          # Numbered R Markdown files run in order (00_, 01_, ...)
│   ├── 00_data_structures.Rmd
│   ├── 01_metadata.Rmd
│   └── ...
└── output/
    ├── figures/
    └── tables/
```

Scripts are numbered to reflect execution order. Each script should be self-contained and reproducible when run top-to-bottom.

## FCS File Naming Convention

Files should be named using the following convention with underscores as separators:

```
YYYYMMDD_mouseID_sex_treatment_timepoint_sampleSource_panel.fcs
```

Example: `20240603_M01_F_Salmonella_D7_SPL_CD8tet.fcs`

| Field | Description | Example |
|---|---|---|
| YYYYMMDD | Date of experiment | 20240603 |
| mouseID | Unique mouse identifier | M01 |
| sex | M or F | F |
| treatment | Free text, no underscores | Salmonella |
| timepoint | Days post infection/treatment prefixed with D | D7 |
| sampleSource | Short abbreviation for tissue or sample type | SPL |
| panel | Short panel name | CD8tet |

## Controlled Vocabularies

### Sex
| Abbreviation | Full Name |
|---|---|
| M | Male |
| F | Female |

### Sample Source
Rather than a fixed controlled vocabulary, sample source follows these rules:
- Use a short, consistent abbreviation (3-5 characters, no spaces)
- Use underscores if two words are necessary (e.g. CD8_EN for CD8 enriched)
- Before starting a new project, define abbreviations in the notes field of experiment_metadata.csv
- Once an abbreviation is used in a project, never change it
- Examples: SPL, MLN, LIV, LNG, PBMC, CULT (for culture)

### Timepoint
Integer days post infection/treatment prefixed with D in filenames (e.g. D0, D7, D14, D28).
For non-infection experiments, define timepoint meaning in experiment_metadata.csv notes field.
Store as integer in metadata tables for modeling purposes.

## Metadata File Specifications

### experiment_metadata.csv
One file per experiment. One row per experiment.

| Field | Description | Example |
|---|---|---|
| experiment_id | Unique identifier, format YYYYMMDD_panel | 20240603_CD8tet |
| date | Date of experiment, YYYY-MM-DD | 2024-06-03 |
| operator | Person who ran samples | Caitlin |
| instrument | Instrument used | Cytek Aurora 3-laser |
| panel_name | Full panel name | CD8 Tetramer Panel |
| panel_version | Panel version number | v1.0 |
| unmixing_operator | Person who performed unmixing in SpectroFlo | Caitlin |
| unmixing_date | Date unmixing was performed, YYYY-MM-DD | 2024-06-04 |
| notes | Deviations from SOP, sample source abbreviations, lot changes | New CD44 lot; SPL = spleen |

### sample_metadata.csv
One row per FCS file.

| Field | Description | Example |
|---|---|---|
| filename | Full FCS filename including extension | 20240603_M01_F_Salmonella_D7_SPL_CD8tet.fcs |
| experiment_id | Join key to experiment_metadata.csv | 20240603_CD8tet |
| mouse_id | Unique mouse identifier | M01 |
| sex | M or F | F |
| cage | Cage number for cage effect regression | C03 |
| treatment | Treatment group | Salmonella |
| timepoint_days | Days post infection/treatment as integer | 7 |
| sample_source | Short abbreviation for tissue or sample type | SPL |
| panel | Panel abbreviation | CD8tet |

### Loading Metadata into a flowSet in R
Always follow this order:
1. Load sample_metadata.csv and experiment_metadata.csv separately
2. Join on experiment_id
3. Match rows to flowSet samples by filename
4. Add to flowSet using pData()

## Domain Knowledge

### The Three Stages of Flow Data

Understanding where your data sits in the pipeline is critical before doing anything in R:

1. **Raw** — raw detector voltages off the instrument. On the Cytek Aurora, this means one value per detector per cell across all 64 detectors. You never work with this directly.
2. **Unmixed** (Aurora-specific) — SpectroFlo decomposes the full detector spectrum into per-fluorochrome values using single-stain reference spectra. **This is what gets loaded into R from an FCS file.** It is not raw — a major mathematical step has already occurred before R is opened.
3. **Transformed** — you apply arcsinh or logicle in R to make data visually and analytically interpretable. This is your responsibility.

Errors at the unmixing stage (poor single-stains, missing autofluorescence extraction, inconsistent reference control gating) cannot be corrected in R. You are always working with the consequences of upstream decisions.

### Checking `$PnE` Before Transforming

Always verify the `$PnE` FCS keyword before applying any transformation to confirm the data is stored as untransformed linear values (`"0,0"`). Anything other than `"0,0"` means a transformation was already applied at export using:

$$y = f_2 \times 10^{\frac{f_1 \cdot x}{R}}$$

where $x$ is the original channel value, $y$ is the scaled value, $f_1$ and $f_2$ are the first and second elements of the `$PnE` key, and $R$ is the channel range from `$PnR`.

```r
keyword(x, c("$P1E", "$P2E", "$P3E"))
```

### Why Transformation Is Necessary

Raw flow data has two problems:
1. **Range** — highly expressed markers can have 100x more signal than dim ones. On a linear scale, dim populations are unresolvable.
2. **Negative values** — after unmixing, cells with no true expression of a marker can have slightly negative values due to noise. Standard log transformation cannot handle negatives.

### Preferred Transformation: Arcsinh

Use arcsinh (cofactor = 150) for Cytek Aurora data. The cofactor controls where the linear-to-log transition occurs. Apply only to fluorochrome columns — not scatter parameters (FSC, SSC), which are already on a meaningful linear scale. See Bendall et al., 2011 in *Science*.

```r
asinhTrans <- arcsinhTransform(transformationId = "arcsinh", a = 0, b = 1/150, c = 0)
transList <- transformList(colnames(x)[4:ncol(x)], asinhTrans)
x_transformed <- transform(x, transList)
```

Logicle (biexponential) is the alternative for conventional flow cytometry — linear near zero, logarithmic at high values. See Parks et al., 2006 in *Cytometry A*.

### Core Data Structures

- `flowFrame` — a single FCS file
- `flowSet` — a collection of `flowFrame`s representing one experiment

```r
names(frames) <- sapply(frames, keyword, "SAMPLE ID")
fs <- as(frames, "flowSet")
```

## Intermediate Object Conventions

Processed R objects are saved as `.rds` files in `data/processed/`. The naming convention mirrors the FCS naming convention and adds a processing stage suffix:

```
YYYYMMDD_panel_stage.rds
```

| Stage suffix | Contents | Example |
|---|---|---|
| `_fs_raw` | flowSet loaded from unmixed FCS, no transformation | `20240603_CD8tet_fs_raw.rds` |
| `_fs_qc` | flowSet after QC filtering (temporal anomalies, margin events removed) | `20240603_CD8tet_fs_qc.rds` |
| `_fs_transformed` | flowSet after arcsinh transformation | `20240603_CD8tet_fs_transformed.rds` |
| `_fs_gated` | flowSet after gating (live, singlets, population of interest) | `20240603_CD8tet_fs_gated.rds` |
| `_counts` | Cell count table derived from gated flowSet | `20240603_CD8tet_counts.rds` |
| `_mfi` | MFI/expression summary table | `20240603_CD8tet_mfi.rds` |

Each script saves its output at the end and the next script loads it by name. Scripts should not re-derive objects that a prior script already produced and saved.

## Reproducibility Requirements

- Always record cage number even if cage effects are not expected
- Always record unmixing operator and date separately from acquisition operator and date
- Never modify files in data/raw/ — all processing starts from data/unmixed/
- Panel versions must be incremented any time antibody lots, clones, or concentrations change
- Notes field in experiment_metadata.csv must document any deviation from SOP
- Sample source abbreviations must be defined in experiment_metadata.csv notes before data collection begins
- Always verify $PnE before transforming any new dataset
