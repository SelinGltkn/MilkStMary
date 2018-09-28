#import required libraries
library(maptools)
library(raster)
library(data.table)
library(tidyverse)

dirRast = 'C:/gis/CDL/MT/'
dirShp = 'C:/Projects/git/MilkStMary/Modeling/Demands/Met Sta Selection/'

# Read in met station locations
metSta = rgdal::readOGR(paste0(dsn = dirShp, layer = 'met_sta_msm.shp'))
metStaDT = data.table(as.data.frame(metSta))

# ghcnSta = rgdal::readOGR(paste0(dsn = dirShp, layer = 'ghcnd_inventory_WGS84.shp'))
# ghcnStaDT = data.table(as.data.frame(ghcnSta))

metStaList = scan(paste0(dirShp, '../mesowestStaSel.txt'), what = character())

metStaFl = metStaDT %>% filter(StationL_1 %in% metStaList)

# ghcnStaDT %>% filter(str_detect(Name, '^CON'))


metStaFl = metSta[metSta$StationL_1 %in% metStaList, ]
rgdal::writeOGR(metStaFl, dsn = dirShp, layer = 'met_msm_fl', driver = 'ESRI Shapefile')
