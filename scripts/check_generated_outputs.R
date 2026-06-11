csv_path <- "data/public/trees.csv"
geojson_path <- "data/public/trees.geojson"

if (!file.exists(csv_path)) {
  stop("Missing generated CSV: ", csv_path, call. = FALSE)
}

if (!file.exists(geojson_path)) {
  stop("Missing generated GeoJSON: ", geojson_path, call. = FALSE)
}

trees <- utils::read.csv(csv_path, stringsAsFactors = FALSE, check.names = FALSE, fileEncoding = "UTF-8-BOM")
if (nrow(trees) < 1) {
  stop("Generated CSV has no rows.", call. = FALSE)
}

geojson <- paste(readLines(geojson_path, warn = FALSE, encoding = "UTF-8"), collapse = "")
if (!grepl("\"type\"[[:space:]]*:[[:space:]]*\"FeatureCollection\"", geojson)) {
  stop("GeoJSON does not contain a FeatureCollection.", call. = FALSE)
}

feature_count <- gregexpr("\"type\"[[:space:]]*:[[:space:]]*\"Feature\"", geojson)[[1]]
feature_count <- if (identical(feature_count, -1L)) 0L else length(feature_count)
if (feature_count != nrow(trees)) {
  stop("GeoJSON feature count does not match CSV row count.", call. = FALSE)
}

message("Generated output check passed: ", nrow(trees), " rows.")

