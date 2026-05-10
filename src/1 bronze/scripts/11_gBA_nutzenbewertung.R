# Download data from "Gemeinsamer Bundesauschluss" (gBA)
# Manual download is possible on 
# https://www.g-ba.de/themen/arzneimittel/arzneimittel-richtlinie-anlagen/nutzenbewertung-35a/ais/#direkter-download
# Automatic download link gets invalid after 3 months inactivity

rm(list = ls())

source <- "https://ais.g-ba.de/download/1a3faa01-e3f5-41b0-9900-bdeb3a4eec7a"
download_file <- "./src/1 bronze/staging area/gBA.xml"

download.file(url = source
              , destfile = download_file
              , method = "libcurl"
              , mode="wb")
