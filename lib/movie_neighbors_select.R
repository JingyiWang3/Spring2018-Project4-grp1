neighbors_select <- function(weights, threshold = 0.5) {
  ## Weight Threshold
  ## Input: weights: weight matrix
  ##        Threshold: weight threshold
  ## Output: A list of neighbors' index for each users
  top.neighbors <- list()
  coverage <- 0
  for(i in 1:nrow(weights)){
    w_i <- weights[i, ]
    ind <- which((abs(w_i) > threshold))
    ind <- ind[ind != i]
    if (length((ind)) == 0) {
      top.neighbors[[i]] <- NA
    } else {
      top.neighbors[[i]] <- ind
    }
  }
  return(top.neighbors)
}