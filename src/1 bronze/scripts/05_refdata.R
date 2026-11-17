# "Präparate" data from Refdata (SAI)

rm(list = ls())

# Load libraries
library(rvest)

# Extract monthly download-link from SAI website
base_url <- "https://sai.refdata.ch"
page <- read_html(paste0(base_url, "/download"))

source <- page %>%
  html_element("table tbody tr:first-child td[data-url]") %>%
  html_attr("data-url")

# Check that a download URL was found
if (is.na(source) || length(source) == 0) {
  stop("Could not find the download URL on the SAI website.")
}

# Download to staging area
download_file <- "./src/1 bronze/staging area/sai.zip"

download.file(url = paste0(base_url, source)
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")

unzip(download_file, exdir = "./src/1 bronze/staging area/", list=TRUE)
unzip(download_file, exdir = "./src/1 bronze/staging area/"
  , files = c("SAI/SAI-Praeparate.XML", "SAI/SAI-Adressen.XML"))


# Delete download file
file.remove(download_file)
