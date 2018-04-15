pred.em<- function (testdata = movie_test, traindata = movie_train, weights, top.neighbors) {
  pred_mat <- matrix(NA, ncol = ncol(testdata), nrow = nrow(testdata))
  test.loc <- !is.na(testdata)
  avg <- apply(traindata, 1, mean, na.rm = T)
  for(i in 1:nrow(traindata)){
    if (is.na(top.neighbors[[i]])) {
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