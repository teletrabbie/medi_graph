# Run all R scripts of bronze layer
# Download source files to bronze staging area

rm(list = ls())

scripts <- c(
  "01_hochteure_medis.R",
  "02_technisches_begleitblatt.R",
  "03_zusatzentgelte.R",
  "04_ema_produkte.R",
  "05_refdata.R",
  "07_bag_sl.R",
  "08_atc_alterations.R",
  "09_antraege.R",
  "11_gBA_nutzenbewertung.R",
  "12_gBA_icd.R"
)

base_dir <- file.path("src", "2 silver", "scripts")
paths <- file.path(base_dir, scripts)

missing <- paths[!file.exists(paths)]
if (length(missing)) warning("Missing scripts: ", paste(basename(missing), collapse = ", "))

invisible(lapply(paths[file.exists(paths)], \(f) source(f, local = FALSE)))