# Flow Cytometry Analysis in R

A reproducible flow cytometry analysis pipeline in R, covering QC, transformation, gating, dimensionality reduction, and statistical analysis. Specific considerations for spectral flow are noted throughout.

**[→ Open the tutorial](https://cbumby17.github.io/flow-analysis-pipeline/)**

## Why R and not FlowJo?

FlowJo is the standard in most flow labs and it's good at what it does. It's fast, visual, and familiar. But it has a reproducibility problem. When you gate in FlowJo, the decisions you make (where you drew the gate, what you excluded, how you defined a population) live in a workspace file that isn't human-readable and doesn't travel well. If someone asks how you got your numbers, the honest answer is often "open my workspace and look." You can't easily version-control it, or hand it to a collaborator who has a different FlowJo version.

In R, every decision is written down. The gate boundaries are in the code. The transformation parameters are in the code. The statistical model is in the code. If you need to rerun the analysis six months later with one sample excluded, you change one line and rerun. If a collaborator wants to apply the same pipeline to their data, they can.

The other practical advantage is that R keeps the entire analysis, from raw FCS files to final statistics, in one place. FlowJo exports numbers to Excel, Excel feeds GraphPad Prism, Prism generates figures. Every handoff is a place where something can go wrong or become disconnected from its source. R eliminates those handoffs.

FlowJo still has a real role for exploratory gating during panel development or quick QC checks, however this pipeline is for the analysis you'd actually report.

## Prerequisites

R ≥ 4.1. Install the required packages:

```r
# CRAN
install.packages(c("tidyverse", "uwot", "lme4", "emmeans", "gridExtra"))

# Bioconductor
if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
BiocManager::install(c("flowCore", "flowWorkspace", "openCyto", "ggcyto", "PeacoQC", "FlowSOM"))
```
