source("common.R")

model_exists <- TRUE

lstm_num_timesteps <- 7
batch_size <- 1
epochs <- 500
lstm_units <- 4
lstm_type <- "stateless"
data_type <- "data_raw"
test_type <- "SEASONAL"

(model_name <- paste(test_type, "_model_lstm_simple", lstm_type, data_type, epochs, "epochs", sep="_"))

# get data into "timesteps form"
X_train <- t(sapply(1:(length(seasonal_train) - lstm_num_timesteps), function(x) seasonal_train[x:(x + lstm_num_timesteps - 1)]))
dim(X_train)
X_train[1:5, ]
y_train <- sapply((lstm_num_timesteps + 1):(length(seasonal_train)), function(x) seasonal_train[x])
y_train[1:5]
X_test <- t(sapply(1:(length(seasonal_test) - lstm_num_timesteps), function(x) seasonal_test[x:(x + lstm_num_timesteps - 1)]))
y_test <- sapply((lstm_num_timesteps + 1):(length(seasonal_test)), function(x) trend_test[x])
# Keras LSTMs expect the input array to be shaped as (no. samples, no. time steps, no. features)
dim(X_train) <- c(dim(X_train)[1], dim(X_train)[2], 1)
dim(X_train)

num_samples <- dim(X_train)[1]
num_steps <- dim(X_train)[2]
num_features <- dim(X_train)[3]
c(num_samples, num_steps, num_features)

dim(X_test) <- c(dim(X_test)[1], dim(X_test)[2], 1)

# model
if (!model_exists) {
  set.seed(22222)
  model <- keras_model_sequential() 
  model %>% 
    layer_lstm(units = lstm_units, input_shape = c(num_steps, num_features)) %>% 
    layer_dense(units = 1) %>% 
    compile(
      loss = 'mean_squared_error',
      optimizer = 'adam'
    )
  
  model %>% summary()
  
  model %>% fit( 
    X_train, y_train, batch_size = batch_size, epochs = epochs, validation_data = list(X_test, y_test)
  )
  model %>% save_model_hdf5(filepath = paste0(model_name, ".h5"))
} else {
  model <- load_model_hdf5(filepath = paste0(model_name, ".h5"))
}

pred_train <- model %>% predict(X_train, batch_size = 1)
pred_test <- model %>% predict(X_test, batch_size = 1)
df <- data_frame(time_id = 1:112,
                 train = c(seasonal_train, rep(NA, length(seasonal_test))),
                 test = c(rep(NA, length(seasonal_train)), seasonal_test),
                 pred_train = c(rep(NA, lstm_num_timesteps), pred_train, rep(NA, length(seasonal_test))),
                 pred_test = c(rep(NA, length(seasonal_train)), rep(NA, lstm_num_timesteps), pred_test))
df <- df %>% gather(key = 'type', value = 'value', train:pred_test)
ggplot(df, aes(x = time_id, y = value)) + geom_line(aes(color = type))

test_rsme <- sqrt(sum((tail(seasonal_test,length(seasonal_test) - lstm_num_timesteps) - pred_test)^2))