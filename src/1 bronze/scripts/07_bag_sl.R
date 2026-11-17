# Download data of "Spezialitätenliste" from BAG

rm(list = ls())

# Load libraries
library(httr2)
library(jsonlite)

# Extract monthly download-link from BAG-SL website
api_url <- "https://epl.bag.admin.ch/api/sl/public/resources/current"

response <- request(api_url) %>%
  req_headers(`Accept-Language` = "de") %>%
  req_perform() %>% 
  resp_body_json(check_type = FALSE)

source <- response$excel$publication$fileUrl

# Check that a download URL was found
if (is.na(source) || length(source) == 0) {
  stop("Could not find the BAG download URL.")
}

# Download to staging area
base_url <- "https://epl.bag.admin.ch/static/"
download_file <- "./src/1 bronze/staging area/Publications.xlsx"

download.file(url = paste0(base_url, source)
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")
