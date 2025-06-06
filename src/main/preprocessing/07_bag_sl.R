# Prepare data of "Spezialitätenliste" from BAG
# Parts of this code probably have been generated by generative AI models

rm(list = ls())

# Load libraries
library(readxl)
library(janitor)


# Download files
sl_file <- "./src/resources/SL-Export.zip"
download.file(url = "https://www.spezialitaetenliste.ch/File.axd?file=XMLPublications.zip"
              ,destfile = sl_file
              , method = "libcurl"
              , mode = "wb")
unzip(sl_file, files="Publications.xlsx" , exdir = "./src/resources/", list=FALSE)


# Import data to environment
Publications <- read_excel("./src/resources/Publications.xlsx", 
                           sheet = "Publications")
colnames(Publications) <- sub(" per.*", "", colnames(Publications))
Publications <- clean_names(Publications)


# Prepare data
Publications$zulassungsnummer <- floor(as.numeric(Publications$swissmedic_nr)/1000)
Publications$zulassungsnummer <- as.character(Publications$zulassungsnummer)

Publications$letzte_preis_anderung <- as.Date(
  ifelse(!is.na(Publications$letzte_preis_anderung),
         Publications$letzte_preis_anderung,
         Publications$einf_datum),
  "%d.%m.%Y")
Publications$einf_datum <- as.Date(Publications$einf_datum, "%d.%m.%Y")


# Export as csv (to import folder of Neo4j)
import_folder <- "./src/main/import"
write.table(Publications, file = paste0(import_folder, "/sl.csv")
            , row.names = FALSE, sep ="|", fileEncoding = "UTF-8")


# Delete resource file
file.remove(sl_file)
