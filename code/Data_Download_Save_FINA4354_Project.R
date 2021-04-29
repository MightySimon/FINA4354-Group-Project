# FINA 4354 Project
# Data download and saving

# Group 2
# Fu Xipeng          3035447805	
# Kong Wong Kai      3035478373
# Tan Zhini          3035478361
# Shiu Chung Haang   3035483653

#===============================================================================

# 1 - Library preparation
# Check if client's computer has the library downloaded,
# then load the required library
list.of.library <- c('xts', 'quantmod', 'ggplot2', 'lubridate')
for (i in list.of.library) {
    print(i)
    if (i %in% rownames(installed.packages()) == FALSE) {
        install.packages(i, character.only = TRUE)
    }
    library(i, character.only = TRUE)
}

# Set working directory if needed
# !!! In the following code, we assume the working directory is
#     the "code" folder under repository root !!!

rm(list.of.library, i) #Free up memory

#===============================================================================

# 2 - Data downloading
# 2.1 - S&P500 data downloading
# S&P500 Index: Underlying
# 10 year for graph plotting, 3 year for parameter calculation
SP500.raw.full <- na.locf(getSymbols("^GSPC",
                                     from = Sys.Date() - years(10),
                                     auto.assign = FALSE))
# S&P500 Total Return Index:
SP500TR.raw <- na.locf(getSymbols("^SP500TR", 
                                  from = Sys.Date() - years(3),
                                  auto.assign = FALSE))
# S&P500 ETF: Hedging
SPY <- na.locf(getSymbols("SPY",
                          from = Sys.Date() - years(3),
                          auto.assign = FALSE))

#-------------------------------------------------------------------------------

# 2.2 - risk-free rate downloading
# We prepare the 1m, 3m, 6m, 1y version of risk-free rate
# If we change the tenor t, we can adopt a different RF rate below
#DGS1MO <- na.locf(getSymbols("DGS1MO", src = "FRED", auto.assign = FALSE))
#DGS3MO <- na.locf(getSymbols("DGS3MO", src = "FRED", auto.assign = FALSE))
DGS6MO <- na.locf(getSymbols("DGS6MO", src = "FRED", auto.assign = FALSE))
#DGS1YR <- na.locf(getSymbols("DGS1", src = "FRED", auto.assign = FALSE))

#===============================================================================

# 3 - Storing data to local repository

# 3.1 - RDS file saving:
data.path <- "../data"
saveRDS(SP500.raw.full, file = file.path(data.path, 'SP500.raw.full.rds'))
saveRDS(SP500TR.raw, file = file.path(data.path, 'SP500TR.raw.rds'))
saveRDS(SPY, file = file.path(data.path, 'SPY.rds'))
saveRDS(DGS6MO, file = file.path(data.path, 'DGS6MO.rds'))

rm(data.path)

#-------------------------------------------------------------------------------

# 3.2 - CSV saving (more visible data):
# change the xts into dataframe
data.path <- "../data"
write.csv(data.frame(row.names = index(SP500.raw.full), 
                     coredata(SP500.raw.full)),
          file = file.path(data.path, 'SP500.raw.full.csv'))
write.csv(data.frame(row.names = index(SP500TR.raw), coredata(SP500TR.raw)),
          file = file.path(data.path, 'SP500TR.raw.csv'))
write.csv(data.frame(row.names = index(SPY), coredata(SPY)),
          file = file.path(data.path, 'SPY.csv'))
write.csv(data.frame(row.names = index(DGS6MO), coredata(DGS6MO)),
          file = file.path(data.path, 'DGS6MO.csv'))

rm(data.path)