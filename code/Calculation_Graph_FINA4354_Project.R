# FINA 4354 Project
# Group 2
# Fu Xipeng          3035447805	
# Kong Wong Kai      3035478373
# Tan Zhini          3035478361
# Shiu Chung Haang   3035483653

rm(list = ls())
options(scipen = 999) # <- prevent using scientific notation

#===============================================================================

# 1 - Library preparation (repeat)
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

rm(list.of.library, i) #Free up memory

#===============================================================================

# 2 - Loading data from local repository
# 2.1 - RDS file loading:
data.path <- "../data"
SP500.raw.full <- readRDS(file = file.path(data.path, 'SP500.raw.full.rds'))
SP500TR.raw <- readRDS(file = file.path(data.path, 'SP500TR.raw.rds'))
SPY <- readRDS(file = file.path(data.path, 'SPY.rds'))
DGS6MO <- readRDS(file = file.path(data.path, 'DGS6MO.rds'))

rm(data.path)

#-------------------------------------------------------------------------------

# 2.2 - CSV file loading:
data.path <- "../data"
SP500.raw.full <- as.xts(read.csv(file = file.path(data.path, 
                                                   'SP500.raw.full.csv'),
                                  row.names = 1))
SP500TR.raw <- as.xts(read.csv(file = file.path(data.path, 'SP500TR.raw.csv'),
                               row.names = 1))
SPY <- as.xts(read.csv(file = file.path(data.path, 'SPY.csv'),
                       row.names = 1))
DGS6MO <- as.xts(read.csv(file = file.path(data.path, 'DGS6MO.csv'),
                          row.names = 1))

rm(data.path)

#===============================================================================

# 3 - Parameter setting
# 3.1 Find the dividend yield with S&P 500
# Get Dividend Yield approximation:
SP500.raw = window(SP500.raw.full, start = Sys.Date() - years(3))
SP500.DayRet <- dailyReturn(SP500.raw$GSPC.Adjusted, 
                            subset = NULL,
                            type = 'log')
SP500TR.DayRet <- dailyReturn(SP500TR.raw$SP500TR.Adjusted,
                              subset = NULL, 
                              type = 'log')

# Get daily return of 2020:
dividend.yield <- sum((SP500TR.DayRet['2020'] - SP500.DayRet['2020']) *
                        SP500.raw['2020',"GSPC.Adjusted"])/
  SP500.raw['2020-12-31',"GSPC.Adjusted"]
q <- as.numeric(coredata(dividend.yield[1]))

cat("Approximated Dividend Yield(q):", 100 * q, "%\n")
rm(SP500TR.DayRet)

#-------------------------------------------------------------------------------

# 3.2 - Find other parameters for the model
n <- nrow(DGS6MO)
# the last day's risk-free rate: note that the rate is in %
r <- as.numeric(coredata(DGS6MO$DGS6MO[n])) / 100
cat("Risk-free rate(r):", 100 * r, "%\n")

n <- nrow(SP500.raw)
# the last day's adjusted index:
S <- as.numeric(coredata(SP500.raw$GSPC.Adjusted[n]))
sigma <- as.numeric(sd(dailyReturn(SP500.raw$GSPC.Adjusted)) * sqrt(252))
t <- 0.5  # tenor
cat("Current S&P500 index(S):", S, "\n")
cat("Volatility(sigma):", sigma, "\n")
cat("Tenor(t):", t, "year(s)\n")

rm(n)  #remove unused variables

#-------------------------------------------------------------------------------

# 3.3 - Find strike prices & step ranges

miu <- as.numeric(mean(dailyReturn(SP500.raw$GSPC.Adjusted)))
# Total expected return in the tenor:
total.miu <- miu * t * 252
cat("Expected return during tenor t =", t, ":", total.miu, "\n")

# period of floating loss: l*S ~ g1*S
l1 <- 0.70    # Barrier level
l2 <- 0.85    # Strike level if DI European put triggered
g1 <- 1 + total.miu             # g1*FV ~ g2*FV is the 1st step
g2 <- 1 + total.miu * 2         # g2*FV ~ g3*FV is the 2nd step
g3 <- 1 + total.miu * 3         # > g3*FV is the 3rd step (ceiling)
cat("l1 =", l1, "\t", "l2 =", l2, "\n")
cat("g1 =", g1, "\t", "g2 =", g2, "\t", "g3 =", g3, "\n")

#===============================================================================

# 4 - Financial models
# 4.1 - Pricing Functions of options used
# S = Spot Price, K = Strike Price, L = Barrier Price
# r = Expected Return, q = Dividend Yield
# sigma = volatility, t = time to maturity

# 4.1.1 - Value of d1
fd1 <- function(S, K, r, q, sigma, t) {
  d1 <- (log(S / K) + (r - q + 0.5 * sigma ^ 2) * t) / (sigma * sqrt(t))
  return(d1)
}

# 4.1.2 - Value of d2
fd2 <- function(S, K, r, q, sigma, t) {
  d2 <- fd1(S, K, r, q, sigma, t) - sigma * sqrt(t)
  return(d2)
}

# 4.1.3 - Price of European call
fBS.call.price <- function(S, K, r, q, sigma, t) { 
  d1 <- fd1(S, K, r, q, sigma, t)
  d2 <- fd2(S, K, r, q, sigma, t)
  price <- S * exp(-q * t) * pnorm(d1) - K * exp(-r * t) * pnorm(d2)
  return(price)
}

# 4.1.4 - Price of European put
fBS.put.price <- function(S, K, r, q, sigma, t) {
  d1 <- fd1(S, K, r, q, sigma, t)
  d2 <- fd2(S, K, r, q, sigma, t)
  price <- K * exp(-r * t) * pnorm(-d2) - S * exp(-q * t) * pnorm(-d1)
  return(price)
}

# 4.1.5 - Price of Down-and-In Barrier Put Option
# Barrier (L) = l1 * S, Strike (K) = l2 * S
fBS.DI.put.price <- function(S, K, L, r, q, sigma, t) {
  const <- (L / S) ^ (2 * (r - q - sigma ^ 2 /2) / (sigma ^ 2))
  price <- const * 
    (fBS.call.price(L ^ 2/ S, K, r, q, sigma, t) - 
       fBS.call.price(L ^ 2/ S, L, r, q, sigma, t) -
       (L - K) * exp(-r * t) * pnorm(fd2(L, S, r, q, sigma, t))) * (K > L) +
    (fBS.put.price(S, min(L, K), r, q, sigma, t) -
       (min(L, K) - K) * exp(-r * t) * 
       pnorm(-fd2(S, min(L, K), r, q, sigma, t)))
  return(price)
}

# 4.1.6 - Price of digital call option
fBS.digital.call.price <- function(S, K, r, q, sigma, t) {
  price <- exp(-r * t) * pnorm(fd2(S, K, r, q, sigma, t))
  return(price)
}

#-------------------------------------------------------------------------------

# 4.2 - Price calculation of each option (and stock per se)
# long stock: S
# D&I barrier:
DI.put <- fBS.DI.put.price(S, l1*S, l2*S, r, q, sigma, t)
# short call at FV:
call <- fBS.call.price(S, g1*S, r, q, sigma, t)
# 1st digital call:
digital.one <- fBS.digital.call.price(S, g2*S, r, q, sigma, t)
# 2nd digital call:
digital.two <- fBS.digital.call.price(S, g3*S, r, q, sigma, t)

# Check the prices of the segments of the portfolio
cat("Replicating portfolio contents & prices:\n")
cat("Long stock:\t\t\t", S, "\n")
cat("Long down-and-in Eur put:\t", DI.put, "\n")
cat("Short Eur call:\t\t\t", -call, "\n")
cat("Long first digital call:\t", digital.one, "(h*S times)\n")
cat("Long second digital call:\t", digital.two, "(h*S times)\n")

#-------------------------------------------------------------------------------

# 4.3 - Exploration of step sizes

# Each step size is h
# If we take total product price = 0.98 * S (2% price as commission fee), then
h = (call - DI.put - 0.02 * S) / (digital.one + digital.two) / S
cat("Step size(h):", h, "\n")

# checking of correctness
total.price = S + DI.put - call + (digital.one + digital.two) * h * S
cat("Total price =", total.price, "S =", S, "\n")
cat("Total price / S =", total.price / S, "\n")

#===============================================================================

# 5 - Hedging formulas
# delta is change of option price against change of underlying price
# In this section, t = tenor, tau = current time = 0

# 5.1 - Delta of European Call/Put
# Beware of the Callput variable when using the functions 
fBS.callput.delta <- function(CallPut, S, K, r, q, sigma, t) {
  d1 <- fd1(S, K, r, q, sigma, t)
  if (CallPut == 'Call') {
    delta <- exp(-q * t) * pnorm(d1)
  }
  else {
    delta <- -exp(-q * t) * pnorm(-d1)
  }
  return(delta)
}

#-------------------------------------------------------------------------------

# 5.2 - Delta of Digital Call
fBS.digital.call.delta <- function(S, K, r, q, sigma, t) {
  const <- exp(-r * t) / (sigma * S * sqrt(t))
  delta <- const * dnorm(fd2(S, K, r, q, sigma, t))
  return(delta)
}

#-------------------------------------------------------------------------------

# 5.3 - Delta of DI European put, by approximation approach
fBS.DI.put.delta.approx <- function(S, K, H, r, q, sigma, t) {
  h <- 0.000001
  upper <- fBS.DI.put.price(S + h / 2, K, H, r, q, sigma, t)
  lower <- fBS.DI.put.price(S - h / 2, K, H, r, q, sigma, t)
  delta.approx <- (upper - lower) / h
}

#-------------------------------------------------------------------------------

# 5.4 - Delta of DI European put, by formula
fBS.DI.put.delta <- function(S, K, L, r, q, sigma, t) {
  v <- (r - q - 0.5 * sigma ^ 2)
  const1 <- (L / S) ^ (2 * v / sigma^2) 
  const1.diff <- L ^ (2 * v / sigma^2) * 
    (-2 * v / sigma^2) * S ^ (-2 * v / sigma^2 -1)
  #C(L^2/S,K)
  call1 <- fBS.call.price(L^2/S, K, r, q, sigma, t)
  delta1 <- (L^2 / S^2) * fBS.callput.delta('Call', L^2/S, K, r, q, sigma, t) 
  #C(L^2/S,L)
  call2 <- fBS.call.price(L^2/S, L, r, q, sigma, t)
  delta2 <- (L^2 / S^2) * fBS.callput.delta('Call', L^2/S, L, r, q, sigma, t) 
  #(L-K)e^(-rt)N(d2(L,S))
  const2 <- (L - K) * exp(-r * t) * pnorm(fd2(L, S, r, q, sigma, t))
  const2.diff <- (L - K) * exp(-r * t) / (S * sigma * sqrt(t)) * 
    dnorm(fd2(L, S, r, q, sigma, t))
  
  deltas.diff <- -delta1 + delta2 + const2.diff
  part1.diff <- const1 * deltas.diff
  
  deltas.nodiff <- call1 - call2 - const2
  part2.diff <- const1.diff * deltas.nodiff
  
  part1 <- part1.diff + part2.diff
  
  part2 <- fBS.callput.delta('Put', S, L, r, q, sigma, t) + 
    (L - K) * exp(-r * t) * dnorm(-1 * fd2(S, L, r, q, sigma, t)) / 
    (S * sigma * sqrt(t))
  
  return(part1 + part2)
}

#-------------------------------------------------------------------------------

# 5.5 - Calculation of component delta
# Delta of long 1 stock is 1, trivially
delta.DI.put <- fBS.DI.put.delta(S, l2*S, l1*S, r, q, sigma, t)
delta.DI.put.approx <- fBS.DI.put.delta.approx(S, l2*S, l1*S, r, q, sigma, t)
delta.call <- -fBS.callput.delta('Call', S, g1*S, r, q, sigma, t)
delta.digital.one <- fBS.digital.call.delta(S, g2*S, r, q, sigma, t)
delta.digital.two <- fBS.digital.call.delta(S, g3*S, r, q, sigma, t)
delta.total <- sum(1, delta.DI.put, delta.call, 
                   h * S * delta.digital.one, h * S * delta.digital.two)

cat("Delta values of each component:\n")
cat("Long Stock:\t\t\t\t 1\n")
cat("Long DI European Put (Calculated):\t", delta.DI.put, "\n")
cat("(Or alternatively:)\n")
cat("Long DI European Put (approximated):\t", delta.DI.put.approx, "\n")
cat("Short European call:\t\t\t", delta.call, "\n")
cat(h*S, "x Long First Digital Call(s):\t", delta.digital.one, "\n")
cat(h*S, "x Long Second Digital Call(s):\t", delta.digital.two, "\n")
cat("Total delta (stock position required):\t", delta.total, "\n")

#===============================================================================

# 6 - Graph plotting
# 6.1 - S&P 500 market trend plot & return Q-Q plot

# Last 10 year S&P500 bar chart
png(file = "../graphs/S&P500_Trend_Last_10_Years.png", 
    width = 800, height = 500)
barChart(SP500.raw.full, theme = "white.mono", bar.type = "hlc")
dev.off()

# Last 3 years S&P500 daily return
png(file = "../graphs/S&P500_Return_QQPlot_Last_10_Years.png", 
    width = 800, height = 500)
qqnorm(SP500.DayRet)
dev.off()
rm(SP500.DayRet)

#-------------------------------------------------------------------------------

# 6.2 - Plot expected payoff graph
# 6.2.1 - Preparation

minprice <- 0.5 * S
maxprice <- 1.5 * S
prices <- seq(minprice, maxprice, 1)
n <- length(prices)

# Payoff setting
payoff.stock <- vector(mode = "numeric", n)
payoff.DI.put.notrigger <- vector(mode = "numeric", n)
payoff.DI.put.trigger <- vector(mode = "numeric", n)
payoff.call <- vector(mode = "numeric", n)
payoff.first.digital.call <- vector(mode = "numeric", n)
payoff.second.digital.call <- vector(mode = "numeric", n)

for (i in 1:n) {
  payoff.stock[i] = prices[i]
  # DI Put: Different payoffs when triggered or not
  payoff.DI.put.notrigger[i] = 0
  payoff.DI.put.trigger[i] = max(l2 * S - prices[i], 0)
  payoff.call[i] = - max(prices[i] - g1*S, 0) #short call
  # h * S number of digital calls
  payoff.first.digital.call[i] = h * S * if(prices[i] > g2*S) 1 else 0
  payoff.second.digital.call[i] = h * S * if(prices[i] > g3*S) 1 else 0
}

# Profit setting
profit.stock <- payoff.stock - as.vector(S)
profit.DI.put.notrigger <- payoff.DI.put.notrigger - as.vector(DI.put)
profit.DI.put.trigger <- payoff.DI.put.trigger - as.vector(DI.put)
profit.call <- payoff.call + as.vector(call)
profit.first.digital.call <- payoff.first.digital.call - 
  h * S * as.vector(digital.one)
profit.second.digital.call <- payoff.second.digital.call - 
  h * S * as.vector(digital.two)

#-------------------------------------------------------------------------------

# 6.2.2 - Combined total payoff when triggered/not triggered
# on PPT page 4,5
# Run 6.2.1 first

payoff.notrigger.overall <- rowSums(cbind(payoff.stock,
                                          payoff.DI.put.notrigger,
                                          payoff.call,
                                          payoff.first.digital.call,
                                          payoff.second.digital.call))

payoff.trigger.overall <- rowSums(cbind(payoff.stock,
                                        payoff.DI.put.trigger,
                                        payoff.call,
                                        payoff.first.digital.call,
                                        payoff.second.digital.call))

combined <- data.frame(cbind(payoff.trigger.overall, payoff.notrigger.overall))
combined[1:(floor(l1*S - minprice)), 2] <- NA

ggplot(combined / S, aes(x = prices / S)) + 
  geom_line(linetype = "dashed", 
            aes(y = payoff.notrigger.overall, color = "Before Triggering")) + 
  geom_line(aes(y = payoff.trigger.overall, color = "After Triggering")) + 
  scale_colour_manual("", 
                      breaks = c("Before Triggering", "After Triggering"),
                      values = c("darkred", "black")) + 
  xlab("ST/S0") +
  ylab("R") +
  ggtitle("Product Payoff Multiplier (R) at Maturity") + 
  annotate(geom = "label", x = 1, y = 0.75, size = 3, 
           label = "When the safety level is triggered") + 
  annotate(geom = 'label', x = 1.2, y = 1, size = 3,
           label = "Ladder Step 1, 2, 3") +
  annotate(geom = "point", x = c(l2, g1, g2, g3), 
           y = c(l2, g1, g1 + h, g1 + 2 * h), 
           size = 7, shape = 21,
           fill = "transparent") +
  annotate(geom = "segment", linetype = "dashed", 
           x = l2, xend = l2 + 0.00000001, 
           y = 0.5, yend = 1.5,
           colour = "blue") +
  xlim(0.5, 1.5) + ylim(0.5, 1.5)

ggsave("../graphs/Payoff_Plot_Combined(P3,4).png", width = 5.4, height = 4)

# cleanup
rm(payoff.trigger.overall, payoff.notrigger.overall, combined)

#-------------------------------------------------------------------------------

# 6.2.3 - Product profit graphs (illustration) when triggered / not
# on PPT page 7,8,9
# Run 6.2.1 first

profit.notrigger.overall <- rowSums(cbind(profit.stock,
                                          profit.DI.put.notrigger,
                                          profit.call,
                                          profit.first.digital.call,
                                          profit.second.digital.call))

profit.trigger.overall <- rowSums(cbind(profit.stock,
                                        profit.DI.put.trigger,
                                        profit.call,
                                        profit.first.digital.call,
                                        profit.second.digital.call))

combined2 <- data.frame(cbind(profit.trigger.overall, profit.notrigger.overall))
combined2[1:(floor(l1*S - minprice)), 2] <- NA

#-------------------------------------------------------------------------------

# graph 1: page 7

ggplot(combined2, aes(x = prices)) + 
  geom_line(linetype = "dashed", 
            aes(y = profit.notrigger.overall, color = "Before Triggering")) + 
  geom_line(linetype = "solid", 
            aes(y = profit.trigger.overall, color = "After Triggering")) + 
  scale_colour_manual("", 
                      breaks = c("Before Triggering", "After Triggering"),
                      values = c("darkred", "black")) + 
  xlab("Underlying Price (ST)") +
  ylab("Profit") +
  ggtitle("Product Profit at Maturity (Before & After Triggering)"
  ) + 
  annotate(geom = "point", x = l2 * S, y = l2 * S - S, size = 45, 
           shape = 21, fill = "transparent", color = "red") +
  annotate(geom = "label", x = 1.18 * S, y = -0.20 * S, size = 5, 
           label = "When the safety level is triggered") + 
  annotate(geom = "segment", linetype = "dashed", 
           x = l2*S, xend = (l2 + 0.00000001) * S, 
           y = -0.5 * S, yend = 0.5 * S,
           colour = "blue") +
  xlim(0.5 * S, 1.5 * S) + ylim(-0.5 * S, 0.5 * S)

ggsave("../graphs/Profit_illustration_1(P7).png", width = 7.5, height = 6)

#-------------------------------------------------------------------------------

# Graph 2 - Page 8

ggplot(combined2, aes(x = prices)) + 
  geom_line(linetype = "dashed", 
            aes(y = profit.notrigger.overall, color = "Before Triggering")) + 
  geom_line(linetype = "solid", 
            aes(y = profit.trigger.overall, color = "After Triggering")) + 
  scale_colour_manual("", 
                      breaks = c("Before Triggering", "After Triggering"),
                      values = c("darkred", "black")) + 
  xlab("Underlying Price (ST)") +
  ylab("Profit") +
  ggtitle("Product Profit at Maturity (Before & After Triggering)"
  ) + 
  annotate(geom = "point", x = (g1 + g2) * S / 2, y = 440, size = 45, 
           shape = 21, fill = "transparent", color = "red") +
  annotate(geom = "point", x = g2 * S, y = (g1 + h - 0.98) * S, 
           size = 8, shape = 21, fill = "transparent")+
  annotate(geom = "point", x = g1 * S, y = (g1 - 0.98) * S, 
           size = 8, shape = 21, fill = "transparent")+
  annotate(geom = 'label', x = 1.2*S, y = 0.04*S, size = 5, label = "g2") +
  annotate(geom = 'label', x = 1.1*S, y = 0, size = 5, label = "g1") +
  xlim(0.5 * S, 1.5 * S) + ylim(-0.5 * S, 0.5 * S)

ggsave("../graphs/Profit_illustration_2(P8).png", width = 7.5, height = 6)

#-------------------------------------------------------------------------------

# Graph 3 - Page 8

ggplot(combined2, aes(x = prices)) + 
  geom_line(linetype = "dashed", 
            aes(y = profit.notrigger.overall, color = "Before Triggering")) + 
  geom_line(linetype = "solid", 
            aes(y = profit.trigger.overall, color = "After Triggering")) + 
  scale_colour_manual("", 
                      breaks = c("Before Triggering", "After Triggering"),
                      values = c("darkred", "black")) + 
  xlab("Underlying Price (ST)") +
  ylab("Profit") +
  ggtitle("Product Profit at Maturity (Before & After Triggering)"
  ) + 
  annotate(geom = "point", x = (g2 + g3) * S / 2, y = 600, size = 45, 
           shape = 21, fill = "transparent", color = "red") +
  annotate(geom = "point", x = g3 * S, y = (g1 + 2 * h - 0.98) * S, 
           size = 8, shape = 21, fill = "transparent") +
  annotate(geom = "point", x = g2 * S, y = (g1 + h - 0.98) * S, 
           size = 8, shape = 21, fill = "transparent") +
  annotate(geom = 'label', x = 1.3 * S, y = 0.1 * S, size = 5, label = "g3") +
  annotate(geom = 'label', x = 1.2 * S, y = 0.04 * S, size = 5, label = "g2") +
  xlim(0.5 * S, 1.5 * S) + ylim(-0.5 * S, 0.5 * S)

ggsave("../graphs/Profit_illustration_3(P9).png", width = 7.5, height = 6)

#-------------------------------------------------------------------------------

# 6.2.3 - Profit graph (split up) when the barrier is not triggered
# on page 12 of PPT
profit.notrigger.overall <- rowSums(cbind(profit.stock,
                                          profit.DI.put.notrigger,
                                          profit.call,
                                          profit.first.digital.call,
                                          profit.second.digital.call,
                                          as.vector(-0.02 * S)))
# Here, 0.02*S commission fee are removed, 
# so the overall line can have a better alignment

# Generate a dataframe for all vectors
# in order to plot the strategy payoffs using ggplot
results.notrigger <- data.frame(cbind(profit.stock,
                                      profit.DI.put.notrigger,
                                      profit.call,
                                      profit.first.digital.call,
                                      profit.second.digital.call,
                                      profit.notrigger.overall))

# Cut off the part lower than barrier
# This causes some warnings, but no impact on plotting
results.notrigger[1:(floor(l1*S - minprice)), ] <- NA

ggplot(results.notrigger, aes(x = prices)) + 
  geom_line(linetype = "dashed", aes(y = profit.stock, color = "Stock")) + 
  geom_line(linetype = "dashed", 
            aes(y = profit.DI.put.notrigger, color = "DI European Put")) +
  geom_line(linetype = "dashed", 
            aes(y = profit.call, color = "European Call")) +
  geom_line(linetype = "dashed", 
            aes(y = profit.first.digital.call, color = "First Digital")) +
  geom_line(linetype = "dashed", 
            aes(y = profit.second.digital.call, color = "Second Digital")) +
  geom_line(aes(y = profit.notrigger.overall, color="Total Profit")) +
  scale_colour_manual("", 
                      breaks = c("Stock", "DI European Put", "European Call", 
                                 "First Digital", "Second Digital", 
                                 "Total Profit"),
                      values = c("darkred", "darkorange", "violet",  
                                 "darkgreen", "darkblue", "black")) + 
  xlab("Underlying Price (ST)") +
  ylab("Profit") +
  ggtitle("Product Profit at Maturity (Not Triggered)") + 
  xlim(0.5 * S, 1.5 * S) + ylim(-0.5 * S, 0.5 * S)

ggsave("../graphs/Profit_Plot_Not_Triggered.png", width = 5.4, height = 4)

#-------------------------------------------------------------------------------

# 6.2.4 - Profit graph (split up) when the barrier is triggered

profit.trigger.overall <- rowSums(cbind(profit.stock,
                                        profit.DI.put.trigger,
                                        profit.call,
                                        profit.first.digital.call,
                                        profit.second.digital.call,
                                        as.vector(-0.02 * S)))

# Generate a dataframe for all vectors
# in order to plot the strategy payoffs using ggplot
results.trigger <- data.frame(cbind(profit.stock,
                                    profit.DI.put.trigger,
                                    profit.call,
                                    profit.first.digital.call,
                                    profit.second.digital.call,
                                    profit.trigger.overall))

ggplot(results.trigger, aes(x = prices)) + 
  geom_line(linetype = "dashed", aes(y = profit.stock, color = "Stock")) + 
  geom_line(linetype = "dashed", 
            aes(y = profit.DI.put.trigger, color = "DI European Put")) +
  geom_line(linetype = "dashed", 
            aes(y = profit.call, color = "European Call")) +
  geom_line(linetype = "dashed", 
            aes(y = profit.first.digital.call, color = "First Digital")) +
  geom_line(linetype = "dashed", 
            aes(y = profit.second.digital.call, color = "Second Digital")) +
  geom_line(aes(y = profit.trigger.overall, color="Total Profit")) +
  scale_colour_manual("", 
                      breaks = c("Stock", "DI European Put", "European Call", 
                                 "First Digital", "Second Digital", 
                                 "Total Profit"),
                      values = c("darkred", "darkorange", "violet",  
                                 "darkgreen", "darkblue", "black")) + 
  xlab("Underlying Price (ST)") +
  ylab("Profit") +
  ggtitle("Product Profit at Maturity (Triggered)") + 
  xlim(0.5 * S, 1.5 * S) + ylim(-0.5 * S, 0.5 * S)

ggsave("../graphs/Profit_Plot_Triggered.png", width = 5.4, height = 4)

#-------------------------------------------------------------------------------

# 6.3 - Plot delta graph
# 6.3.1 - Preparation

minprice <- 0.5 * S
maxprice <- 1.5 * S
prices <- seq(minprice, maxprice, 1)
n <- length(prices)

# delta setting

graph.delta.DI.put <- vector(mode = "numeric", n)
graph.delta.call <- vector(mode = "numeric", n)
graph.delta.digital.one <- vector(mode = "numeric", n)
graph.delta.digital.two <- vector(mode = "numeric", n)
graph.delta.overall <- vector(mode = "numeric", n)

for (i in 1:n) {
  graph.delta.DI.put[i] = 
    fBS.DI.put.delta(prices[i], l2*S, l1*S, r, q, sigma, t)
  graph.delta.call[i] = 
    -1 * fBS.callput.delta('Call', prices[i], g1*S, r, q, sigma, t)
  graph.delta.digital.one[i] = 
    fBS.digital.call.delta(prices[i], g2*S, r, q, sigma, t)
  graph.delta.digital.two[i] = 
    fBS.digital.call.delta(prices[i], g3*S, r, q, sigma, t)
  graph.delta.overall[i] = graph.delta.DI.put[i] + graph.delta.call[i] + 
                           graph.delta.digital.one[i] + 
                           graph.delta.digital.two[i]
}

#-------------------------------------------------------------------------------

# 6.3.2 - Delta at start date
results.delta <- data.frame(cbind(graph.delta.DI.put, 
                                  graph.delta.call, 
                                  graph.delta.digital.one, 
                                  graph.delta.digital.two,
                                  graph.delta.overall))

ggplot(results.delta, aes(x = prices)) + 
  geom_line(linetype = "dashed", 
            aes(y = graph.delta.DI.put, color = "DI Put delta")) + 
  geom_line(linetype = "dashed", 
            aes(y = graph.delta.call, color = "European Call delta")) +
  geom_line(linetype = "dashed", 
            aes(y = graph.delta.digital.one, color = "First Digital delta")) +
  geom_line(linetype = "dashed", 
            aes(y = graph.delta.digital.two, color = "Second Digital delta")) +
  geom_line(linetype = "solid",
            aes(y = graph.delta.overall, color="Total Delta")) +
  scale_colour_manual(breaks = c("DI Put delta", "European Call delta", 
                                 "First Digital delta", "Second Digital delta", 
                                 "Total Delta"),
                      values = c("violet", "darkorange","darkgreen", "darkblue", 
                                 "black")) + 
  xlab("Underlying Price") +
  ylab("Delta") +
  ggtitle("Delta at Start Date") 
ggsave("../graphs/Delta_Breakdown_Beginning.png", width = 5.7, height = 4)

#-------------------------------------------------------------------------------

# 6.3.3 - Delta at different maturity date
graph.delta.1day <- vector(mode = "numeric", n)
graph.delta.1week <- vector(mode = "numeric", n)
graph.delta.1month <- vector(mode = "numeric", n)
graph.delta.3month <- vector(mode = "numeric", n)
graph.delta.6month <- vector(mode = "numeric", n)

for (i in 1:n) {
  graph.delta.DI.put[i] = 
    fBS.DI.put.delta(prices[i], l2*S, l1*S, r, q, sigma, 1/252)
  graph.delta.call[i] = 
    -1 * fBS.callput.delta('Call', prices[i], g1*S, r, q, sigma, 1/252)
  graph.delta.digital.one[i] = 
    fBS.digital.call.delta(prices[i], g2*S, r, q, sigma, 1/252)
  graph.delta.digital.two[i] = 
    fBS.digital.call.delta(prices[i], g3*S, r, q, sigma, 1/252)
  graph.delta.1day[i] = 
    graph.delta.DI.put[i] + graph.delta.call[i] + 
    graph.delta.digital.one[i] + graph.delta.digital.two[i]
}

for (i in 1:n) {
  graph.delta.DI.put[i] = 
    fBS.DI.put.delta(prices[i], l2*S, l1*S, r, q, sigma, 5/252)
  graph.delta.call[i] = 
    -1 * fBS.callput.delta('Call', prices[i], g1*S, r, q, sigma, 5/252)
  graph.delta.digital.one[i] = 
    fBS.digital.call.delta(prices[i], g2*S, r, q, sigma, 5/252)
  graph.delta.digital.two[i] = 
    fBS.digital.call.delta(prices[i], g3*S, r, q, sigma, 5/252)
  graph.delta.1week[i] = graph.delta.DI.put[i] + graph.delta.call[i] + 
    graph.delta.digital.one[i] + graph.delta.digital.two[i]
}

for (i in 1:n) {
  graph.delta.DI.put[i] = 
    fBS.DI.put.delta(prices[i], l2*S, l1*S, r, q, sigma, 21/252)
  graph.delta.call[i] = 
    -1 * fBS.callput.delta('Call', prices[i], g1*S, r, q, sigma, 21/252)
  graph.delta.digital.one[i] = 
    fBS.digital.call.delta(prices[i], g2*S, r, q, sigma, 21/252)
  graph.delta.digital.two[i] = 
    fBS.digital.call.delta(prices[i], g3*S, r, q, sigma, 21/252)
  graph.delta.1month[i] = graph.delta.DI.put[i] + graph.delta.call[i] + 
    graph.delta.digital.one[i] + graph.delta.digital.two[i]
}

for (i in 1:n) {
  graph.delta.DI.put[i] = 
    fBS.DI.put.delta(prices[i], l2*S, l1*S, r, q, sigma, 84/252)
  graph.delta.call[i] = 
    -1 * fBS.callput.delta('Call', prices[i], g1*S, r, q, sigma, 84/252)
  graph.delta.digital.one[i] = 
    fBS.digital.call.delta(prices[i], g2*S, r, q, sigma, 84/252)
  graph.delta.digital.two[i] = 
    fBS.digital.call.delta(prices[i], g3*S, r, q, sigma, 84/252)
  graph.delta.3month[i] = graph.delta.DI.put[i] + graph.delta.call[i] + 
    graph.delta.digital.one[i] + graph.delta.digital.two[i]
}

for (i in 1:n) {
  graph.delta.DI.put[i] = 
    fBS.DI.put.delta(prices[i], l2*S, l1*S, r, q, sigma, 126/252)
  graph.delta.call[i] = 
    -1 * fBS.callput.delta('Call', prices[i], g1*S, r, q, sigma, 126/252)
  graph.delta.digital.one[i] = 
    fBS.digital.call.delta(prices[i], g2*S, r, q, sigma, 126/252)
  graph.delta.digital.two[i] = 
    fBS.digital.call.delta(prices[i], g3*S, r, q, sigma, 126/252)
  graph.delta.6month[i] = 
    graph.delta.DI.put[i] + graph.delta.call[i] + 
    graph.delta.digital.one[i] + graph.delta.digital.two[i]
}

results.delta.maturity <- data.frame(cbind(graph.delta.1day,
                                           graph.delta.1week,
                                           graph.delta.1month,
                                           graph.delta.1month,
                                           graph.delta.1month))

ggplot(results.delta, aes(x = prices)) + 
  geom_line(linetype = "solid", 
            aes(y = graph.delta.1day, color = "1 Day")) + 
  geom_line(linetype = "solid", 
            aes(y = graph.delta.1week, color = "1 Week")) +
  geom_line(linetype = "solid", 
            aes(y = graph.delta.1month, color = "1 Month")) +
  geom_line(linetype = "solid", 
            aes(y = graph.delta.3month, color = "3 Month")) +
  geom_line(linetype = "solid",
            aes(y = graph.delta.overall, color = "6 Month")) +
  scale_colour_manual(breaks = c("1 Day", "1 Week", 
                                 "1 Month", "3 Month", 
                                 "6 Month"),
                      values = c("violet", "darkorange","darkgreen", "darkblue", 
                                 "black")) + 
  xlab("Underlying Price") +
  ylab("Delta") +
  ggtitle("Total Delta at Different Time to Maturity")

ggsave("../graphs/Delta_Different_TTM.png", width = 5.1, height = 4)

#-------------------------------------------------------------------------------

# cleaning up if you wish
rm(prices)
rm(payoff.stock, payoff.DI.put.notrigger, payoff.DI.put.trigger, payoff.call, 
   payoff.first.digital.call, payoff.second.digital.call)
rm(profit.stock, profit.DI.put.notrigger, profit.DI.put.trigger, profit.call, 
   profit.first.digital.call, profit.second.digital.call,
   profit.notrigger.overall, profit.trigger.overall)

rm(graph.delta.1day, graph.delta.1month, graph.delta.1week,
   graph.delta.3month, graph.delta.6month)
rm(graph.delta.call, graph.delta.DI.put, graph.delta.digital.one, 
   graph.delta.digital.two, graph.delta.overall)
rm(results.delta, results.delta.maturity, 
   results.notrigger, results.trigger)
