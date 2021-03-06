# will need to merge rowise, possibly rename, point at two directories and so on.

library(plyr)
library(reshape)
library(ggplot2)
setwd("C:/Users/Alberto/Documents/swarm_runs/T2_Std_s") 
listOfFiles_first <- list.files("C:/Users/Alberto/Documents/swarm_runs/T2_Std_s", 
                          pattern="*.csv", recursive=TRUE) # filenames of output 40-320 cells

numberCA_first<- as.numeric(gsub("[^0-9]", "", listOfFiles_first)) # vector with the number of CA updates as numeric from the filenames
CAOrdered_first <- sort(numberCA_first) # order the number of CA ascendingly
inds_first <- sort.int(numberCA_first, index.return=TRUE)[[2]] # extract index of the numberCA in ascending order
listOfFiles_first<- listOfFiles_first[order(listOfFiles_first)[inds_first]] # reorders the list on ascending number of CA updates

read.special<-function(x) { # file reader
        read.csv(x, header=T, sep='\t', dec='.') 
}
allData_first <- lapply(listOfFiles_first, read.special) # reads all the output files

# built-in function to drop the comma as thousand separator and drop the undesired columns from the dataframes
dataReducer <- function(data) { 
        data[,8] <- as.numeric(gsub(",","", data[,8])) # drop the comma as thousand separator
        data[,2] <- as.numeric(gsub(",","", data[,2])) # drop the comma as thousand separator
        data[,2] <- as.numeric(data[,2]) # turn to numeric class the Grid column
        data <- data[c(2,6,7,8)] # extract the desired columns
}

allData_first <- lapply(allData_first, dataReducer) # reduces dataframes

# second block

setwd("C:/Users/Alberto/Documents/swarm_runs/T2_Std_sa6") 
listOfFiles_second <- list.files("C:/Users/Alberto/Documents/swarm_runs/T2_Std_sa6", 
                          pattern="*.csv", recursive=TRUE) # # filenames of output 640-1280 cells

numberCA_second<- as.numeric(gsub("[^0-9]", "", listOfFiles_second)) # vector with the number of CA updates as numeric from the filenames
CAOrdered_second <- sort(numberCA_second) # order the number of CA ascendingly
inds_second <- sort.int(numberCA_second, index.return=TRUE)[[2]] # extract index of the numberCA in ascending order
listOfFiles_second<- listOfFiles_second[order(listOfFiles_second)[inds_second]] # reorders the list on ascending number of CA updates

allData_second <- lapply(listOfFiles_second, read.special) # reads all the output files
allData_second <- lapply(allData_second, dataReducer) # reduces dataframes
cellsOrdered <- c(40,80,160,320,640,1280) # vector with the meaningful grid sizes
cellSize <- c(500,250,125,62.500,31.250,15.625) # vector with the dimensions of the cells



# merging

completeData <- list()
for (i in 1:length(allData_first)) {
        completeData[[i]] <- rbind(allData_first[[i]], allData_second[[i]])
}

subset.custom <- function(data) { # function to keep only the meaningful numbers of cells
        subset(data, data$CellGridSize %in% (cellsOrdered))
}

completeData <- lapply(completeData, subset.custom) 

# code region to exclude the school expanse outliers from the dataframe. school expanse upper limit
# corresponds to numFish(30) + 40 = 70. 

subsetter <- function(data) { 
        data1 <- subset(data, data[,4]<=70) # careful with scoping rules, rename variables
        data1 <- data1[,c(1,2,3)] # drops the expanse column once it's not necessary anymore
}
completeDataSub <- lapply(completeData, subsetter) 

# routine
mainRoutine <- function(X) { 
        stdError <- function(x) sqrt(var(x)/length(x)) # function defining standard error
        stdErrorColumn<-function(X) apply(X[,2:ncol(X)], 2, stdError) # function to apply stdError to columns
        meanPerCellGridSize <- ddply(X, .(CellGridSize), colMeans) # apply mean factorized by cell grid size
        stdErrorPerCellGridSize <- ddply(X, .(CellGridSize), stdErrorColumn) # apply stdErrorColumn factorized by numFish
        meanAndStdError <- merge(meanPerCellGridSize, stdErrorPerCellGridSize, by="CellGridSize")
}

allDataFrames <- lapply(completeDataSub, mainRoutine) # applies the routine to all the dataframes

CAList <- list()
for (i in 1:length(CAOrdered_first)) { # create a list of vectors, each a replicate of an updating time
        CAList[[i]] <- rep(CAOrdered_first[i], nrow(allDataFrames[[i]]))
}
for (i in 1:length(allDataFrames)) { # merges cellList to the data frames
        allDataFrames[[i]]$CAUpdate <- CAList[[i]]
}
for (i in 1:length(allDataFrames)) { # renames the columns of the data frames
        colnames(allDataFrames[[i]])<- c("Grid", "Foodpatch", "Fishonfood", "fp_se", "fof_se", "CAupdate")
}
for (i in 1:length(allDataFrames)) { # divides fish on food by number of cells (standardization)
        allDataFrames[[i]]$fishOnFoodStd <- allDataFrames[[i]][,3]/allDataFrames[[i]][,2]
}
for (i in 1:length(allDataFrames)) { # calculates the standard error of the new variable (according to error propagation rules)
        allDataFrames[[i]]$fishOnFoodStd_se <- sqrt((allDataFrames[[i]][,5]/allDataFrames[[i]][,3])^2+
                                                               (allDataFrames[[i]][,4]/allDataFrames[[i]][,2])^2)
}


# data reorganization
temp <- as.data.frame(matrix(nrow=nrow(allDataFrames[[1]]), ncol=length(allDataFrames)))
for (i in 1:length(allDataFrames)) {
        temp[,i] <- allDataFrames[[i]][,length(allDataFrames[[i]])-1] 
}
temp2 <- as.data.frame(matrix(nrow=nrow(allDataFrames[[1]]), ncol=length(allDataFrames)))
for (i in 1:length(allDataFrames)) {
        temp2[,i] <- allDataFrames[[i]][,length(allDataFrames[[i]])] 
}

fishOnFoodPerUpdateTime <- data.frame(cellSize, temp, temp2)
fishOnFoodPerUpdateTime <- fishOnFoodPerUpdateTime[with(fishOnFoodPerUpdateTime, order(cellSize)), ]
colnames(fishOnFoodPerUpdateTime)<- c("Cellsize", "t2", "t4", "t8", "t16", "t32", "t64", "se2", "se4", "se8", "se16",
                        "se32", "se64")
meltFishOnFoodPerUpdateTime <- melt(fishOnFoodPerUpdateTime, id.vars="Cellsize")

# mapping of the limits for the error bars in the plot
limitsa<-aes(ymax=fishOnFoodPerUpdateTime$t2+fishOnFoodPerUpdateTime$se2, ymin=fishOnFoodPerUpdateTime$t2-fishOnFoodPerUpdateTime$se2)
limitsb<-aes(ymax=fishOnFoodPerUpdateTime$t4+fishOnFoodPerUpdateTime$se4, ymin=fishOnFoodPerUpdateTime$t4-fishOnFoodPerUpdateTime$se4)
limitsc<-aes(ymax=fishOnFoodPerUpdateTime$t8+fishOnFoodPerUpdateTime$se8, ymin=fishOnFoodPerUpdateTime$t8-fishOnFoodPerUpdateTime$se8)
limitsd<-aes(ymax=fishOnFoodPerUpdateTime$t16+fishOnFoodPerUpdateTime$se16, ymin=fishOnFoodPerUpdateTime$t16-fishOnFoodPerUpdateTime$se16)
limitse<-aes(ymax=fishOnFoodPerUpdateTime$t32+fishOnFoodPerUpdateTime$se32, ymin=fishOnFoodPerUpdateTime$t32-fishOnFoodPerUpdateTime$se32)
limitsf<-aes(ymax=fishOnFoodPerUpdateTime$t64+fishOnFoodPerUpdateTime$se64, ymin=fishOnFoodPerUpdateTime$t64-fishOnFoodPerUpdateTime$se64)


plotFishOnFoodPerUpdateTime <-ggplot(subset(meltFishOnFoodPerUpdateTime, variable=="t2" | variable=="t4" |
                                            variable== "t8" | variable== "t16" | variable== "t32" | 
                                      variable== "t64"),
                             aes(x=Cellsize, y=value, fill=variable))+
        geom_line(aes(linetype=variable), size=0.2)+
        scale_linetype_manual(values=c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash"))+
        geom_point(aes(shape=variable, fill=variable), size=3)+
        #coord_trans(x="log2")+
        scale_shape_manual(values=c(25,22,23,24,21,7))+
        scale_fill_manual(values=rep("darkgrey",6))+
        scale_x_log10("Cell size", breaks=cellSize)+
        scale_y_continuous("Fish on food", breaks=seq(0,5, by=0.5), 
                           limits=c(0,5), expand=c(0,0))+
        geom_errorbar(limitsa, data=subset(meltFishOnFoodPerUpdateTime, variable=="t2"), width=0.02, position='dodge')+
        geom_errorbar(limitsb, data=subset(meltFishOnFoodPerUpdateTime, variable=="t4"), width=0.02, position='dodge')+
        geom_errorbar(limitsc, data=subset(meltFishOnFoodPerUpdateTime, variable=="t8"), width=0.02, position='dodge')+
        geom_errorbar(limitsd, data=subset(meltFishOnFoodPerUpdateTime, variable=="t16"), width=0.02, position='dodge')+
        geom_errorbar(limitse, data=subset(meltFishOnFoodPerUpdateTime, variable=="t32"), width=0.02, position='dodge')+        
        geom_errorbar(limitsf, data=subset(meltFishOnFoodPerUpdateTime, variable=="t64"), width=0.02, position='dodge')+        
        theme_bw()+
        theme(panel.grid.major.x = element_blank())+
        theme(axis.title.x = element_text(size=12,vjust=-0.3),
              axis.title.y = element_text(size=12,vjust=1))+
        theme(legend.title = element_text(size=12))+
        theme(axis.text.x=element_text(size=10))+
        theme(axis.text.y=element_text(size=10))

plotFishOnFoodPerUpdateTime # render the plot, can be commented out as routine

write.table(fishOnFoodPerUpdateTime, "C:/Users/Alberto/Documents/swarm_runs/new_output_CA/update_swarm_reverted.csv")

ggsave("update_swarm_reverted.pdf", plotFishOnFoodPerUpdateTime, useDingbats=FALSE)
