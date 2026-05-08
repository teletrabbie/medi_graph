# Download data of "Spezialitätenliste" from BAG

rm(list = ls())

source <- "https://www.spezialitaetenliste.ch/File.axd?file=XMLPublications.zip"
download_file <- "./src/1 bronze/staging area/SL-Export.zip"

download.file(url = source
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")

unzip(download_file, exdir = "./src/1 bronze/staging area/"
  , files = "Publications.xlsx")


# Delete resource file
file.remove(download_file)
