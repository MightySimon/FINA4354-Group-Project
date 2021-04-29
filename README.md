# FINA 4354 Project

## Group members
- Fu Xipeng          3035447805
- Kong Wong Kai      3035478373
- Tan Zhini          3035478361
- Shiu Chung Haang   3035483653

## Code executing instructions
1. Reminders
- The codes assume that the current working directory of R is "./code", i.e. the "code" folder under the repository root. If not, please set the WD to that folder for an error free running.
- The codes may contain many segments and sub-segments. If you only wish to run some of the segments only, select those (sub-)segments and run.
- Note that some segments must be run before other segments, otherwise there will be errors due to lack of variables.

2. Open file "Data_Download_Save_FINA4354_Project.R" and run the code
- This code downloads necessary data and saves them into the local repository.
- Default save path is "./data" under the repository root.
- If there is already up-to-date data inside the directory, this step can be skipped.
- Both RDS-saving and CSV-saving methods are provided. Both methods provide the same results, you can use either method as you wish.

3. Open file "Calculation_Graph_FINA4354_Project.R" for calculation
* This is the master code.
* For this file, insturction is given for each section.
(2): Data loading
- Similar to data saving, both RDS-loading and CSV-loading methods are given.

(3): Parameter setting
- Parameters to be determined in this section:
- dividend yield(q), risk-free rate(r), initial stock price(S), volatility(sigma), tenor(t) (Note T is not used since this will mix with TRUE)
- Product design factors: l1, l2, g1, g2, g3 and the intermediate factor total.miu
- h will be determined later as a result of calculation
- After calculation, they will be printed to the screen

(4): Financial models
- (4.1) Functions calculating the European call, put, down-and-in European put, digital call are provided. Run this segment before (4.2).
- (4.2) Calculate the price of each component (stock, options) and print to the screen.
- (4.3) Determine step size h according to the assumptions.

(5): Delta hedging
- Delta hedging functions are provided for all components, but they are not necessarily a good option to take. These are just for reference.
- (5.1-5.4) Delta functions. Run this segment before (5.2).
- Note that when S and t changes, the delta functions can be used to simulate the changes of delta(s) when time approaches to maturity (with stock price changing accordingly). This is used in (6.3)
- (5.5) Calculation of current delta (at the time of purchase) and print to the screen

(6): Graph plotting
- All plots are saved in the "./graphs" for your reference.
- (6.1) S&P trend plot and return Q-Q plot are produced and saved.
- (6.2) Profit graphs:
  - (6.2.2-6.2.3) There are two graphs showing a split up of replicating portfolio profits. There are two graphs since barrier option will alter the profit graph after triggering.
  - (6.2.4) There is also a simple total profit graph combining the before/after triggering cases.
- (6.3) Delta graphs:
  - (6.3.1) Delta graph or each component (and total) at the start date, illustrating their sensitivity to the price.
  - (6.3.2) Total Delta graph for different maturities, showing the the sensitivity to price change when approaching the maturity.
  
Thank you for your patience.
