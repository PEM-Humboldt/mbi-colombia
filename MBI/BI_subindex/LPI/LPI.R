## Code to calculate the Living Planet Index 
### Using the git repository of de Zoological Society of London and their R package rlpi - https://github.com/Zoological-Society-of-London/rlpi
#### Instal rlpi
install.packages("devtools")
library(devtools)
# Install from main ZSL repository online
install_github("Zoological-Society-of-London/rlpi", dependencies=TRUE, force = TRUE)

# Load packages
packages <- c("rstudioapi","sf","dplyr","terra","rlpi","ggplot2")
lapply(packages,require,character.only=T)

# Set as working directory where the script is saved
dirfolder<- dirname(getSourceEditorContext()$path)
setwd(dirfolder)

####LPI CODE----

#Upload file with species table addresses, group and corresponding weights.For the species tables is important to remove NAs (trailing years with no data)
lpi_col <- read.table("data/LPI_Matrix.txt", header = T)

# LPI calculation, default gives 100 bootstraps. It save result tables in the data folder and plot the result
col_lpi <- LPIMain("data/LPI_Matrix.txt", REF_YEAR = 2005, use_weightings = 1, VERBOSE=FALSE,CI_FLAG = 1, BOOT_STRAP_SIZE = 100)

# Remove NAs (trailing years with no data)
col_lpi_2 <- col_lpi[complete.cases(col_lpi), ]
# This produces a simple plot, but we can use ggplot_lpi to produce a nicer version
ggplot_lpi(col_lpi_2, ylims=c(0, 2))


