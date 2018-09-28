#import required libraries
library(maptools)
library(raster)
library(data.table)
library(tidyverse)
library(OpenStreetMap)

dirRast = 'C:/gis/CDL/MT/'
dirShp = 'C:/Projects/git/MilkStMary/Modeling/Demands/Met Sta Selection/'

# Read in met station locations
metSta = rgdal::readOGR(paste0(dsn = dirShp, layer = 'met_sta_msm.shp'))
metSta100m = rgdal::readOGR(paste0(dsn = dirShp, layer = 'met_sta_msm_100m.shp'))
metSta1600m = rgdal::readOGR(paste0(dsn = dirShp, layer = 'met_sta_msm_1600m.shp'))

metStaDT = data.table(as.data.frame(metSta))
metStaDT$ID = 1:nrow(metStaDT)
metStaDT = metStaDT %>% dplyr::select(ID, StationL_1, StationNam, Elevation, Longitude, Latitude)

cdlCodeTbl = fread(paste0(dirShp, '../cdlCodes.csv'))
#list files (in this case raster TIFFs)
cdlDatList = list.files(dirRast, pattern = "*.tif$")

ctCDL = length(cdlDatList)

bufrList = c(100, 1600)
ctBufr = length(bufrList)
for(iterBufr in 1:ctBufr)
  bufrSel = bufrList[iterBufr]
  metStaClsStat = data.table()
  for(iterCDL in 1:ctCDL){
    cdlSel = cdlDatList[iterCDL]
    cdlYear = unlist(str_split(cdlSel, '_'))[2]
    cdlTemp = raster(paste0(dirRast, cdlSel))
    metStaCls = raster::extract(cdlTemp, metSta, df = T, buffer = bufrSel)
    metStaClsDT = data.table(metStaCls) %>%
      setNames(c('ID', 'CDLCode'))

    metStaClsStatTmp = metStaClsDT %>% group_by(ID, CDLCode) %>%
      dplyr::summarise(CellCount = n()) %>%
      group_by(ID) %>%
      mutate(TotalCellCount = sum(CellCount)) %>%
      mutate(Percent = round(CellCount / TotalCellCount * 100)) %>%
      mutate(CDLYear = cdlYear, Buffer = paste0(bufrSel, 'm')) %>%
      left_join(cdlCodeTbl) %>%
      ungroup()
      metStaClsStat = bind_rows(metStaClsStat, metStaClsStatTmp)
  }
  metStaClsStat = metStaClsStat %>% left_join(metStaDT)
  write.csv(metStaClsStat, paste0(dirShp, 'met_msm_', bufrSel, 'm_CDL.csv'))
}

# Read In Data and Plot
metStaClsStat100 = fread(paste0(dirShp, 'met_msm_100m_CDL.csv'))
metStaClsStat100 = metStaClsStat100 %>%
  left_join(cdlCodeTbl)

metStaClsStat100 = metStaClsStat100 %>%
  group_by(CDLYear, Buffer, TotalCellCount, StationL_1, StationNam, Class) %>%
  dplyr::summarise(CellCount = sum(CellCount)) %>%
  mutate(Percent = (CellCount / TotalCellCount) * 100) %>%
  ungroup()

metStaClsStat100 = metStaClsStat100 %>%
  filter(Class %in% c('Crop', 'Grassland/Pasture')) %>%
  dplyr::rename(Percent50m = Percent) %>%
  dplyr::select(-Buffer, -TotalCellCount, -CellCount)

metStaClsStat1600 = fread(paste0(dirShp, 'met_msm_1600m_CDL.csv'))
metStaClsStat1600 = metStaClsStat1600 %>%
  left_join(cdlCodeTbl)

metStaClsStat1600 = metStaClsStat1600 %>%
  group_by(CDLYear, Buffer, TotalCellCount, StationL_1, StationNam, Class) %>%
  dplyr::summarise(CellCount = sum(CellCount)) %>%
  mutate(Percent = (CellCount / TotalCellCount) * 100) %>%
  ungroup()

metStaClsStat1600 = metStaClsStat1600 %>%
  filter(Class %in% c('Crop', 'Grassland/Pasture'))%>%
  dplyr::rename(Percent1600m = Percent) %>%
  dplyr::select(-Buffer, -TotalCellCount, -CellCount)


metStaClsComb = metStaClsStat1600 %>%
  left_join(metStaClsStat100)
metStaClsComb = metStaClsComb %>% mutate(Percent50m = ifelse(is.na(Percent50m), 0, Percent50m))

metStaFl = metStaClsComb %>% filter(Percent50m >= 50, Percent1600m >= 75)

metStaFlList = unique(metStaFl$StationL_1)
ctSta = length(metStaFlList)

yrList = 2007:2017
ctYr = length(yrList)

clsList = c('Crop', 'Grassland/Pasture')
ctCls = length(clsList)

distList = c('100m', '1600m')
ctDist = length(distList)

tmpDatFrm = data.table(StationL_1 = metStaFlList, CDLYear = rep(yrList, each = ctSta),
  Class = rep(clsList, each = ctSta*ctYr), Distance = rep(distList, each = ctSta*ctYr*ctCls))
tmpDat = metStaClsStat100 %>% dplyr::rename(Percent = Percent50m) %>%
  mutate(CDLYear = as.numeric(CDLYear)) %>%
  dplyr::select(-StationNam) %>%
  mutate(Distance = '100m')
tmpDat2 = metStaClsStat1600 %>% dplyr::rename(Percent = Percent1600m) %>%
  mutate(CDLYear = as.numeric(CDLYear)) %>%
  dplyr::select(-StationNam) %>%
  mutate(Distance = '1600m')
tmpDat3 = bind_rows(tmpDat, tmpDat2)
datPlot = tmpDatFrm %>%
  left_join(tmpDat3) %>%
  mutate(Percent = ifelse(is.na(Percent), 0, Percent))

# 77, 88
for(iterSta in 91:ctSta){

  staSel = metStaFlList[iterSta]
  metStaClsSel = datPlot %>% filter(StationL_1 == staSel)
  metStaClsSel$CDLYear = as.numeric(metStaClsSel$CDLYear)
  ggplot(data = metStaClsSel) +
    geom_line(aes(x = CDLYear, y = Percent, color = Class, linetype = Distance)) +
    # geom_line(aes(x = CDLYear, y = Percent1600m, color = Class), linetype = 2) +
    ggtitle(staSel) + geom_hline(yintercept = c(50, 80), linetype = 2, colour = 'gray20') +
    theme_bw() +
    scale_x_continuous(breaks = 2007:2017) + xlab('Year') + ylab('Percent') +
    scale_y_continuous(limits = c(0, 100))

    ggsave(paste0(dirShp, 'figures/', staSel, 'CDLPercents.png'), height = 4, width = 6)

    metStaDatFl = metStaDT %>% filter(StationL_1 == staSel)

    mapTmp = openmap(c(metStaDatFl$Latitude + 0.025, metStaDatFl$Longitude - 0.025),
      c(metStaDatFl$Latitude - 0.025, metStaDatFl$Longitude + 0.025), type = 'bing')

    png(paste0(dirShp, 'figures/', staSel, 'Map.png'), height = 4, width = 2.8, units = 'in', res = 300)
      plot(mapTmp)
      mapTempProj = "+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs"
      metStaSel = metSta[metSta$StationL_1 == staSel, ]
      metSta100mSel = metSta100m[metSta100m$StationL_1 == staSel, ]
      metSta1600mSel = metSta1600m[metSta1600m$StationL_1 == staSel, ]
      metStaSel = spTransform(metStaSel, mapTempProj)
      metSta100mSel = spTransform(metSta100mSel, mapTempProj)
      metSta1600mSel = spTransform(metSta1600mSel, mapTempProj)
      plot(metSta1600mSel, add = T)
      plot(metSta100mSel, add = T)
      plot(metStaSel, add = T, pch = 4)
    dev.off()
}
