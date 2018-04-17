###################### Load data ######################
train <- read.csv("../data/eachmovie_sample/data_train.csv", stringsAsFactors = FALSE)
test <- read.csv("../data/eachmovie_sample/data_test.csv", stringsAsFactors = FALSE)

train <- train[,-1]
test <- test[,-1]

# Number of Unique Movies
length(unique(train[, 1])) # 1619

# Number of Unique Users
length(unique(train[, 2])) # 5055


###################### Reshape data ######################
train.new <- reshape(train, v.names = "Score", direction = "wide", idvar = "User", timevar = "Movie")
test.new <- reshape(test, v.names = "Score", direction = "wide", idvar = "User", timevar = "Movie") 

# Save file
# save(train.new, file = "../output/movie_train_wide.Rdata")
# save(test.new, file = "../output/movie_test_wide.Rdata")

# load("../output/movie_train_wide.Rdata") # train.new
# load("../output/movie_test_wide.Rdata") # test.new

###################### Check the number of each unique score ######################
# The first column is the user number.
sum(is.na(train.new[, -1])) # 7374519
length(which(train.new[, -1] == 1)) # 126204
length(which(train.new[, -1] == 2)) # 45872
length(which(train.new[, -1] == 3)) # 103515
length(which(train.new[, -1] == 4)) # 204078
##### Cut off
length(which(train.new[, -1] == 5)) # 204857
length(which(train.new[, -1] == 6)) # 125000

# We need to transform the wide data frame to a new matirx which only contains 0 and 1.
# After checking the number of each unique score, 
# we deicide all NA, 0, 1, 2, 3 values will become 0, and 4, 5, 6 will become 1.
###################### Form matrix only contains 0 and 1 ######################
train.mat <- as.matrix(train.new[, -1])
colnames(train.mat) <- NULL
rownames(train.mat) <- NULL

for(i in 1 : nrow(train.mat)){
  for(j in 1 : ncol(train.mat)){
    # Threshold 
    if(is.na(train.mat[i, j]) | train.mat[i, j] <= 4){
      train.mat[i, j] <- 0
    }else{
      train.mat[i, j] <- 1
    } 
  }
}

# Save file
# save(train.mat, file = "../output/movie_train_mat.Rdata")
# load("../output/movie_train_mat.Rdata")

###################### Form the matrix w ######################
# dim(train.mat) user: 5055 movie: 1619
mat.right.up <- matrix(rep(0, nrow(train.mat)*nrow(train.mat)), nrow = nrow(train.mat))
upper.mat <- cbind(mat.right.up, train.mat)
mat.left.low <- matrix(rep(0, ncol(train.mat)*ncol(train.mat)), nrow = ncol(train.mat))
lower.mat <- cbind(t(train.mat), mat.left.low)
w <- rbind(upper.mat, lower.mat) 
# dim(w) 5055 + 1619 = 6674

# assign column name and row name for matix mat
colnames(w) <- c(train.new[, 1], colnames(train.new)[-1])
rownames(w) <- colnames(w)
 
# w matrix -- column normalize
w.colsum <- colSums(w)

# column normalize function
normalize <- function(vec){
  return(vec/w.colsum)
}
w <- apply(w, 1, normalize)
w[is.na(w)] <- 0

# save(w, file = "../output/w.Rdata")
# load("../output/w.Rdata")

###################### Calculate Simrank ######################
# iterate 5 times to obtain the matrix S
simrank.func <- function(c = 0.8, w){
  for(i in 1:5){
    S <- diag(nrow(w))
    print(i)
    S <- c * (t(w) %*% S %*% w)
    diag(S) <- 1
  }
  return(S)
}

# save(S, file = "../output/S.Rdata")
# load("../output/S.Rdata")

# s_user is the users similarity matrix
s_user <- S[1:5055, 1:5055]
# save(s_user, file = "../output/s_user.Rdata")
# load("../output/s_user.Rdata")

source("memory.new.R")
############### Selecting Neighborhoods - weight_threshold ################
top.neighbors <- neighbors_select(s_user, 0.0003)
top.neighbors.none <- neighbors_select(s_user, 0)

###################### Prediction ######################
pre.sim <- pred.em(test.new[, -1], train.new[, -1], s_user, top.neighbors)
pre.sim.none <- pred.em(test.new[, -1], train.new[, -1], s_user, top.neighbors.none)

###################### Evaluation ######################
test.new <- as.matrix(test.new)

## MAE
sim_mae <- mae(pre.sim, test.new[, -1])
sim_mae # 1.051652

sim_mae_none <- mae(pre.sim.none, test.new[, -1])
sim_mae_none # 1.060127

## ROC
# roc_value = 4
sim_roc <- roc(4, pre.sim, test.new[, -1])
sim_roc # 1.060127

sim_roc_none <- roc(4, pre.sim.none, test.new[, -1])
sim_roc_none # 0.7377874

