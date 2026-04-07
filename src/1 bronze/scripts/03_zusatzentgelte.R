# Download supplemtent list (Zusatzentgelte) to staging area

rm(list = ls())

staging_path <- "./src/1 bronze/staging area/"
source <- "https://www.swissdrg.org/download_file/view/5383/2330"
download_file <- paste0(staging_path, "ze_katalog.zip")

download.file(url = source
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")


# Extract only definitions file and rename it
zip_files <- unzip(download_file, exdir = "./src/1 bronze/staging area/", list=TRUE)$Name
definitions_file <- zip_files[grep("definitions", zip_files)]
unzip(download_file, exdir = "./src/1 bronze/staging area/", files = definitions_file)

file.rename(from = paste0(staging_path, definitions_file),
            to = paste0(staging_path, 'definitions.csv'))


# Delete download file
file.remove(download_file)
