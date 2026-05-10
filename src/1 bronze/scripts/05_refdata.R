# "Präparate" data from Refdata (SAI)

rm(list = ls())

source <- "https://sai.refdata.ch/download/structuredexportzip/8876"
download_file <- "./src/1 bronze/staging area/sai.zip"

download.file(url = source
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")

unzip(download_file, exdir = "./src/1 bronze/staging area/", list=TRUE)
unzip(download_file, exdir = "./src/1 bronze/staging area/"
  , files = c("SAI/SAI-Praeparate.XML", "SAI/SAI-Adressen.XML"))


# Delete download file
file.remove(download_file)
