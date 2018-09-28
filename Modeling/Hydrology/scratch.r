
library(tidyverse)
library(data.table)
setwd('C:/Projects/StMaryMilkRiverBasins/tmp')

soilTmp = fread('vic.nldas.mexico.soil')



lonMin = -114.09375
lonMax = -106.03125

latMin = 47.71875
latMax = 49.78125

test = soilTmp %>%
  filter(V4 >= lonMin, V4 <= lonMax, V3 >= latMin, V3 <= latMax)

test2 = sort(unique(test$V4))
write.csv(test2, 'longitude_list.txt', row.names = F, quote = F)
test3 = sort(unique(test$V3))
write.csv(test3, 'latitude_list.txt', row.names = F, quote = F)

test4 = test %>% dplyr::select(V3, V4) %>%
  setNames(c('Lat', 'Lon'))
write.csv(test4, 'coord_tbl.csv', row.names = F, quote = F)
