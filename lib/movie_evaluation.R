###################### MAE ######################
mae <- function (pred_mat, test_mat) {
  ## function to calculate mean absolute error of predicted value
  ## Input: pred_mat - predicted matrix
  ##        test_mat - test data matrix
  ## Output: MAE
  mae <- mean(abs(pred_mat - test_mat), na.rm = T)
  return(mae)
}

###################### ROC ######################
roc <- function (roc_value, pred_mat, test_mat) {
  match <- sum((pred_mat >= roc_value) == (test_mat >= roc_value), na.rm=TRUE)
  n <- sum(!is.na(pred_mat))
  return(match/n)
}