# Download data of "Spezialitätenliste" from BAG

rm(list = ls())

source <- "https://epl.bag.admin.ch/static/sl/publication/excel/foph-sl-publication-20261103-de.xlsx"
download_file <- "./src/1 bronze/staging area/Publications.xlsx"

download.file(url = source
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")
