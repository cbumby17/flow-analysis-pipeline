# Run this script to render the full tutorial site to docs/.
# Output goes to docs/ which is served by GitHub Pages.
# Run from the project root: Rscript render_site.R

library(rmarkdown)

root <- normalizePath(".")
dir.create("docs/scripts", recursive = TRUE, showWarnings = FALSE)

render_script <- function(path, ...) {
  cat("Rendering:", basename(path), "... ")
  tryCatch(
    render(path,
           output_dir    = file.path(root, "docs/scripts/"),
           knit_root_dir = root,
           quiet         = TRUE,
           ...),
    error = function(e) cat("\n  ERROR:", conditionMessage(e), "\n")
  )
  cat("done\n")
}

# Index page
render("index.Rmd", output_dir = "docs/", knit_root_dir = root, quiet = TRUE)
cat("Rendered: index\n")

# Scripts must run in order — each depends on the previous script's saved output
render_script("scripts/01_load_and_metadata.Rmd")
render_script("scripts/02_qc.Rmd")
render_script("scripts/03_transformation.Rmd")
render_script("scripts/04_gating.Rmd")
render_script("scripts/05_dimensionality_reduction.Rmd")
render_script("scripts/06_clustering.Rmd")
render_script("scripts/07_analysis.Rmd")

cat("\nSite rendered to docs/. Commit and push to update GitHub Pages.\n")
