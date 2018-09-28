library(tidyverse)
library(httr)
library(jsonlite)

# https://api.mesowest.net/v2/stations/timeseries?stid=mscm8&start=199701010000&end=201812310000&output=csv

endPt = 'https://api.mesowest.net/v2/'
staRqst = 'stations/timeseries?stid='
dateRqst = '&start=199701010000&end=201812310000'
otpRqst = '&output=json'
tknRqst = '&token=9f084cfd461244ae948d1c3ea4c7f0d5'
staId = 'mscm8'
repos = GET(url = paste0(endPt, staRqst, staId, dateRqst, otpRqst, tknRqst))
repo_content = content(repos)


library(tidyverse)
library(httr)
library(jsonlite)
repos = GET(url = 'http://api.mesowest.net/v2/stations/metadata?&output=geojson&token=9f084cfd461244ae948d1c3ea4c7f0d5')

repo_contents = content(repos)

write(repo_contents, 'mesowest_metadata_all.geojson')

mswMetaAPI = fromJSON('http://api.mesowest.net/v2/stations/metadata?&output=json&token=9f084cfd461244ae948d1c3ea4c7f0d5')
mswMetaTbl = mswMetaAPI$STATION
mswMetaTbl = data.table(mswMetaTbl)
write.csv(mswMetaTbl, 'mesowest_metadata_all.csv', row.names = F, quote = F)
