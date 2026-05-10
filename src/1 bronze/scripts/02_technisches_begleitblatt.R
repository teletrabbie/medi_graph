# Download "Technisches Begleitblatt" to staging area

rm(list = ls())

source <- "https://www.swissdrg.org/download_file/view/5323/2390"
download_file <- "./src/1 bronze/staging area/Technisches_Begleitblatt.xlsx"

download.file(url = source
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")
