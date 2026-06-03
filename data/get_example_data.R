# Downloads and formats the GvHD teaching dataset for use with this tutorial.
# Source: Srivastava et al. (2008), distributed via the flowCore R package.
# Run this script once before working through the tutorial scripts.
#
# The GvHD dataset is a longitudinal flow cytometry study of bone marrow
# transplant patients monitored for graft-versus-host disease. It is
# conventional (not spectral) flow data from a FACScan instrument.
# Fluorescence channels are stored log-amplified ($PnE = "4,0"), not as
# linear untransformed values — this differs from Cytek Aurora unmixed FCS
# files where $PnE = "0,0". Script 03 explains how to handle both cases.

library(flowCore)
library(tidyverse)

data(GvHD)

dir.create("data/unmixed", recursive = TRUE, showWarnings = FALSE)
dir.create("metadata", showWarnings = FALSE)

meta <- pData(GvHD) %>%
  rownames_to_column("original_name") %>%
  mutate(
    patient_id = paste0("P", sprintf("%02d", Patient)),
    treatment   = case_when(Grade == 0 ~ "Healthy", TRUE ~ "GvHD"),
    gvhd_grade  = Grade,
    timepoint_days = Days,
    sample_source  = "PBL",
    panel          = "tcell",
    experiment_id  = "GvHD_tcell",
    filename = paste0(patient_id, "_V", sprintf("%02d", Visit), ".fcs")
  )

# Write each sample as an FCS file
for (i in seq_len(length(GvHD))) {
  ff <- GvHD[[i]]
  out_path <- file.path("data/unmixed", meta$filename[i])
  write.FCS(ff, out_path)
}

cat("Wrote", length(GvHD), "FCS files to data/unmixed/\n")

# experiment_metadata.csv
experiment_meta <- tibble(
  experiment_id    = "GvHD_tcell",
  date             = NA_character_,
  operator         = "Srivastava_et_al",
  instrument       = "FACScan",
  panel_name       = "T Cell Panel",
  panel_version    = "v1.0",
  unmixing_operator = NA_character_,
  unmixing_date    = NA_character_,
  notes = paste(
    "Teaching dataset: Srivastava et al. GvHD study via flowCore package.",
    "Grade 0 = no GvHD; Grade 1 = mild; Grade 3 = severe.",
    "Days = days post bone marrow transplant.",
    "Conventional cytometer data: $PnE is '4,0' for fluorescence channels",
    "(log-amplified at acquisition). Do not apply arcsinh — see script 03."
  )
)

write_csv(experiment_meta, "metadata/experiment_metadata.csv")

# sample_metadata.csv
sample_meta <- meta %>%
  select(
    filename, experiment_id, patient_id, treatment, gvhd_grade,
    timepoint_days, sample_source, panel
  )

write_csv(sample_meta, "metadata/sample_metadata.csv")

cat("Wrote metadata/experiment_metadata.csv\n")
cat("Wrote metadata/sample_metadata.csv\n")
