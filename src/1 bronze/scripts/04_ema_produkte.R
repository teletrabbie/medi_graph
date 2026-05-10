# Download data from European Medicines Agency (EMA)

rm(list = ls())

source <- "https://www.ema.europa.eu/en/documents/report/medicines-output-medicines-report_en.xlsx"
download_file <- "./src/1 bronze/staging area/medicines_output_medicines_report_en.xlsx"

download.file(url = source
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")
