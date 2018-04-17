#Turn raw data into sparse matrix
reshape_ms <- function(data){
  ## input: raw MS data
  ## output: MS sparse matrix
  user_ind = which(data$V1 == "C")
  user_id = data$V2[data$V1 == "C"]
  matrix = matrix(0, nrow =length(user_ind),ncol = length( unique(data$V2) )-length(user_ind))
  rownames(matrix) = user_id
  colnames(matrix) = sort(setdiff(unique(data$V2), user_id))
  
  for(i in 1:(length(user_ind)-1)){
    v = as.character(data$V2[(user_ind[i]+1):(user_ind[i+1]-1)])
   # print(i)
    matrix[i, v] = 1
  }
  v = as.character(data$V2[(user_ind[length(user_ind)]+1):nrow(data)])
  matrix[length(user_ind),v] = 1
  return(matrix)
}





## Similarity Weighting
sim_weights <- function(data, weight) {
  ## calculate similarity weight
  ## input: data - EachMovie data in wide form
  ##        weight - "pearson" or "vector"
  ## output: similarity weight matrix
  stopifnot(weight == "pearson"|weight == "vector")
  library(lsa)
  data <- as.matrix(data)
  if (weight == "vector") {
    data[is.na(data)] <- 0
    return(cosine(t(data)))
  } else if (weight == "pearson") {
    return(cor(t(data), use = "pairwise.complete.obs", method = "pearson"))
  }
}



sim_weights_ms <- function(data, weight) {
  ## calculate similarity weight
  ## input: data - MS sparse matrix
  ##        weight - "pearson" or "vector"
  ## output: similarity weight matrix
  stopifnot(weight == "pearson"|weight == "vector")
  library("lsa")
  if (weight == "vector") {
    return(cosine(t(data)))
  } else if (weight == "pearson") {
    return(cor(t(data),method = "pearson"))
  }
}

### Simrank
simrank.func <- function(c = 0.8, w){
  ## Input: c - damping factor
  ##        w - column-normalized matrix of the adjacency matrix of graph G 
  ## Output: similarity weight matrix
  S <- diag(nrow(w))
  for(i in 1:5){
    print(i)
    S <- c * (t(w) %*% S %*% w)
    diag(S) <- 1
  }
  s_user <- S[1:5055, 1:5055]
  return(s_user)
}


## Variance Weighting
sim_var <- function(data) {
  # find variance weights for each item
  data <- as.matrix(data)
  v <- rep(NA, ncol(data))
  var_vec <- apply(data, 2, na.rm = TRUE, var)
  var_max <- max(var_vec, na.rm = TRUE)
  var_min <- min(var_vec, na.rm = TRUE)
  v <- (var_vec - var_min)/var_max
  n <- nrow(data)
  w <- matrix(NA, nrow = n, ncol = n)
  data.t <- apply(data, 1, scale)
  for (a in 1:n) {
    print(a)
    for (u  in 1:n) {
        # compute var_pearson weight mat
        z_a <- data.t[ ,a]
        z_u <- data.t[ ,u]
        ind <- (!is.na(z_a)) & (!is.na(z_u))
        w[a, u] <- v[ind]%*%(z_a[ind]*z_u[ind])/sum(v[ind])
    }
  }
  return(w)
}

sim_var_ms <- function(data) {
  ## input: data - MS sparse matrix
  ## output: variance adjusted similarity weight matrix 
  
  v <- rep(NA, ncol(data))
  var_vec <- apply(data, 2, na.rm = TRUE, var)
  var_max <- max(var_vec, na.rm = TRUE)
  var_min <- min(var_vec, na.rm = TRUE)
  v <- (var_vec - var_min)/var_max
  n <- nrow(data)
  w <- matrix(NA, nrow = n, ncol = n)
  data.t <- apply(data, 1, scale)
  for (a in 1:n) {
    print(a)
    for (u  in 1:n) {
      # compute var_pearson weight mat
      z_a <- data.t[ ,a]
      z_u <- data.t[ ,u]
      w[a, u] <- v %*% (z_a * z_u)/sum(v)
    }
  }
  return(w)
}


## Selecting Neighbors - weight_threshold
neighbors_select <- function(weights, threshold = 0.5) {
  ## Weight Threshold
  ## Input: weights - weight matrix
  ##        Threshold - weight threshold
  ## Output: A list of neighbors' index for each users
  top.neighbors <- list()
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


## Prediction
pred.em<- function (testdata = movie_test, traindata = movie_train, weights, top.neighbors) {
  ## make prediction of Movie Data
  ## Input: testdata - movie test data matrix
  ##        traindata - movie train data matrix
  ##        weights - weight matrix
  ##        top.neighbors - A list of neighbors' index for each users
  ## Output: a predicted matrix
  pred_mat <- matrix(NA, ncol = ncol(testdata), nrow = nrow(testdata))
  test.loc <- !is.na(testdata)
  avg <- apply(traindata, 1, mean, na.rm = T)
  # neighbor.weights = try[user,top.neighbors]
  for(i in 1:nrow(traindata)){
    if (is.na(top.neighbors[[i]][1])) {
      pred_mat[i, test.loc[i, ]] <- round(avg[i], 0)
    } else {
      pred_movie <- colnames(testdata)[!is.na(testdata[i,])]
      neighbor.weights <- weights[i,top.neighbors[[i]]]
      neighbor.ratings <- traindata[top.neighbors[[i]], pred_movie]
      neighbor.avg <- avg[top.neighbors[[i]]]
      pred_mat[i, test.loc[i, ]] <- round(avg[i] +   
                                            apply((neighbor.ratings - neighbor.avg) *   
                                                    neighbor.weights, 2, sum, na.rm = T) /   
                                            sum(neighbor.weights, na.rm = T), 0)
    }
  }
  return(pred_mat)
}


pred.ms <- function (test, train, weights, top.neighbors) {
  
  pred.matrix = matrix(0, nrow = nrow(test),ncol = ncol(train))
  rownames(pred.matrix) = rownames(test)
  colnames(pred.matrix) = colnames(train)
  
  average_rating = apply(train, 1, mean)
  for(i in 1:nrow(pred.matrix)){
    useid = rownames(test)[i]
    neighbourid = top.neighbors[[i]]
    
    ra = average_rating[i]
    rui = train[neighbourid,]
    ru = average_rating[neighbourid]
    
    #print(i)
    if(is.na(neighbourid[1])){
      pred.matrix[i,] = ra
    }else if(!is.na(neighbourid[1]) & length(neighbourid) == 1){
      
      new_weight = t( (rui-ru) ) * weights[i,neighbourid] /sum(weights[i,neighbourid])
      pred.matrix[i,] = new_weight  + ra
    }else{
      new_weight = t( (rui-ru) ) %*% weights[i,neighbourid] /sum(weights[i,neighbourid]) 
      pred.matrix[i,] = new_weight  + ra
    }
  }
  
  return(pred.matrix[,colnames(test)])
}

## Evaluation
## MAE
mae <- function (pred_mat, test_mat) {
  ## calculate mean absolute error of predicted value
  ## Input: pred_mat - predicted matrix
  ##        test_mat - test data matrix
  ## Output: MAE
  mae <- mean(abs(pred_mat - test_mat), na.rm = T)
  return(mae)
}

## ROC
roc <- function (roc_value = 4, pred_mat, test_mat) {
  ## calculate roc-4 for predicted value
  ## Input: roc_value - threshold
  ##        pred_mat - predicted matrix
  ##        test_mat - test data matrix
  ## Output: ROC-4
  match <- sum((pred_mat >= roc_value) == (test_mat >= roc_value), na.rm=TRUE)
  n <- sum(!is.na(pred_mat))
  return(match/n)
}


## Rank Score
rank_score <- function(pred,test){
  ## calculate rank score of predicted matrix
  ## input: pred - predicted matrix of test data
  ##        test - test data matrix
  ## output: rank score
  
  d <- 0.03
  rank_pred <- ncol(pred)+1-t(apply(pred,1,function(x){return(rank(x,ties.method = 'first'))}))
  rank_test <- ncol(test)+1-t(apply(test,1,function(x){return(rank(x,ties.method = 'first'))}))
  vec = ifelse(test - d > 0, test - d, 0)
  Rank_a <- apply(1/(2^((rank_pred-1)/4)) * vec,1,sum)
  Rank_a_max <- apply(1/(2^((rank_test-1)/4)) * vec,1,sum)
  R <- 100*sum(Rank_a)/sum(Rank_a_max)
  return(R)
}

