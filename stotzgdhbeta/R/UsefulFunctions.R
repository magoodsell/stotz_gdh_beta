
# //? - What exactly does it do?
# data retrival
load_index_data <- function(){
  tf <- tempfile()
  chunk_index_url <- "https://hrrrzarr.s3.amazonaws.com/grid/HRRR_chunk_index.h5"
  download.file(chunk_index_url, tf, mode="wb")
  nc_data <- nc_open(tf)
  unlink(tf)
  return(nc_data)
}

# //? - What exaclty does it do?
# data retrival
get_chunk_info <- function(lat, lon, nc_data){
  coords <- c(lon, lat)
  my_point_sfc <- st_sfc(st_point(coords), crs=4326)
  hrrr_proj = "+proj=lcc +lat_1=38.5 +lon_1=38.5 +lon_0=262.5 +lat_0=38.5 +R=6371229"
  my_point_sfc_t <- st_transform(my_point_sfc, hrrr_proj)
  my_point_t <- as.vector(as.data.frame(my_point_sfc_t)$geometry[[1]])
  x_t <- my_point_t[1]
  y_t <- my_point_t[2]
  x <- which.min( abs(nc_data$dim$x$vals - x_t) )
  y <- which.min( abs(nc_data$dim$y$vals - y_t) )
  chunk_id <- ncvar_get(nc_data, "chunk_id")[x,y]
  chunk_id_fixed <- stri_reverse(chunk_id)
  in_chunk_x <- ncvar_get(nc_data, "in_chunk_x")[x]
  in_chunk_y <- ncvar_get(nc_data, "in_chunk_y")[y]
  return(c(chunk_id_fixed, as.numeric(in_chunk_y), as.numeric(in_chunk_x)))
}

###
# //? - What does this do exactly
# data retrival
get_url <- function(gdh_date, chunk_id){
  return (sprintf("https://hrrrzarr.s3.amazonaws.com/sfc/%s/%s/surface/TMP/surface/TMP/%s",
                  strftime(gdh_date, "%Y%m%d"),
                  strftime(gdh_date,"%Y%m%d_%Hz_anl.zarr"),
                  chunk_id))
}

###
# //? - What does this do exactly
# data retrival
read_grid_from_url <- function(hrrr_url){
  np <- import("numpy")
  ncd <- import("numcodecs")
  tf <- tempfile()
  return_flag <- FALSE
  tryCatch(
    expr = {
      download.file(hrrr_url, tf, mode="wb", method="libcurl", quiet=TRUE)
    },
    error = function(e){
      message('Could not download file from URL, setting temp to NA')
      print(hrrr_url)
      return_flag <<- TRUE
      return(0)
    }
  )
  if(return_flag){
    return(NA)
  }
  raw_chunk_data <- readBin(file(tf,"rb"), "raw", file.info(tf)$size)
  unlink(tf)
  return(
    np$reshape(np$frombuffer(ncd$blosc$decompress(raw_chunk_data), dtype='<f2'), c(150L, 150L))
  )
}

###
# //? -
# data retrival it seems
get_temp_from_date <- function(gdh_date, chunk_id, in_chunk_x, in_chunk_y){
  print(gdh_date)
  temp_grid <- read_grid_from_url(get_url(gdh_date, chunk_id))
  # supressWarnings() is here because is.na() will give a warning if checking an array
  # all() is needed as well to check if all elements are NA
  if(all(is.na(temp_grid))){
    return(NA)
  }
  return(temp_grid[in_chunk_x, in_chunk_y])
}

###
# seems to be temp_info group
get_temp_from_date_range <- function(min_date, max_date, chunk_id, in_chunk_x, in_chunk_y){
  dates_to_get <- seq(as.POSIXct(min_date, tz="GMT"), as.POSIXct(max_date, tz="GMT"), by="hour")
  temp_df <- as.data.frame(dates_to_get) %>%
    dplyr::rename(date=dates_to_get) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(temp_k = get_temp_from_date(date, chunk_id, in_chunk_x, in_chunk_y)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(temp_f = 1.8*(temp_k-273.15)+32)
  return(temp_df$temp_f)
}

###

convert_list_col <- function(data_to_concat, data, name_col){
  range <- 1:nrow(data)

  new_ft <- data.frame()

  for (val in range){
    temp_frame <- data.frame(t(do.call(data.frame, dt[val])))
    new_ft <- rbind.fill(new_ft, temp_frame)
  }

  new_ft <- cbind(data_to_concat, new_ft)
  return(new_ft)
}

###
# //N - Not sure what this is used for
purrf <- function(la, lo) {
  get_chunk_info(la, lo, nc_data = nc_data)
}

###
# data retrival
## Gets the data from amazon database - HRRR
get_chunks <- function(
    x = c("2.2", "2.3", "3.3", "4.2", "4.3"),
    max_date = lubridate::ymd("2022-01-01"),
    min_date = lubridate::ymd("2019-09-01"),
    rows = NULL) {

  dates_to_get <- seq(
    as.POSIXct(min_date, tz="GMT"),
    as.POSIXct(max_date, tz="GMT"),
    by="hour")

  combos <- expand.grid(dates_to_get, x) |>
    mutate(urls = get_url(Var1, Var2))

  if (!is.null(rows)) combos <- combos[1:rows,]

  grids <- purrr::map(combos$url, ~read_grid_from_url(.x))

  out <- combos |>
    mutate(grid = purrr::map(grids, as_tibble))
}

###

get_temp_from_date_cdat <- function(gdh_date, chunk_id, in_chunk_x, in_chunk_y){

  cdat <- get_chunks()
  temp_grid <- cdat %>%
    dplyr::filter(Var1 == gdh_date, Var2 == chunk_id)

  temp_grid_temp <- tryCatch(temp_grid[[4]][[1]][in_chunk_x, in_chunk_y], error=function(err) NA)

  return(temp_grid_temp)
}

###

get_temp_from_date_range_cdat <- function(min_date, max_date, chunk_id, in_chunk_x, in_chunk_y){
  dates_to_get <- seq(as.POSIXct(min_date, tz="GMT"), as.POSIXct(max_date, tz="GMT"), by="hour")
  temp_df <- as.data.frame(dates_to_get) %>%
    dplyr::rename(date=dates_to_get) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(temp_k = get_temp_from_date_cdat(date, chunk_id, in_chunk_x, in_chunk_y)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(temp_f = 1.8*(temp_k-273.15)+32)

  return(list(temp_df$temp_f))
}
