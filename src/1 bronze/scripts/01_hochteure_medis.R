# Download "Liste der hochteuren Medikamente/Substanzen" to staging area

rm(list = ls())

source <- "https://www.swissdrg.org/download_file/view/5319/2390"
download_file <- "./src/1 bronze/staging area/hochteure_medis.csv"

download.file(url = source
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")
