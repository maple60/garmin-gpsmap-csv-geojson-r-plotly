required_tree_columns <- c(
  "tree_id",
  "lat",
  "lon",
  "species_jp",
  "scientific_name",
  "survey_date",
  "observer",
  "accuracy_m",
  "publish",
  "note_public"
)

public_tree_columns <- c(
  required_tree_columns,
  "family_jp",
  "marker_color"
)

default_marker_palette <- c(
  "#1f7a5a",
  "#b45f24",
  "#3f6fb5",
  "#8a5a9e",
  "#2f7f8f",
  "#9a6b1f",
  "#5b7f2a",
  "#b14e5c"
)

read_settings <- function(path = "config/settings.csv") {
  if (!file.exists(path)) {
    stop("Settings file not found: ", path, call. = FALSE)
  }

  settings <- utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = "",
    fileEncoding = "UTF-8-BOM"
  )

  if (!all(c("key", "value") %in% names(settings))) {
    stop("Settings file must have key and value columns: ", path, call. = FALSE)
  }

  values <- settings$value
  values[is.na(values)] <- ""
  names(values) <- trimws(settings$key)
  as.list(values)
}

setting_value <- function(settings, key, default = "") {
  value <- settings[[key]]
  if (is.null(value) || is.na(value) || !nzchar(trimws(value))) {
    return(default)
  }
  trimws(value)
}

env_or_setting <- function(env_name, settings, key, default = "") {
  env_value <- Sys.getenv(env_name, unset = "")
  if (nzchar(trimws(env_value))) {
    return(trimws(env_value))
  }
  setting_value(settings, key, default)
}

is_url <- function(path) {
  grepl("^https?://", path, ignore.case = TRUE)
}

read_csv_source <- function(source) {
  if (!nzchar(trimws(source))) {
    stop("CSV source is empty.", call. = FALSE)
  }

  if (!is_url(source) && !file.exists(source)) {
    stop("CSV source not found: ", source, call. = FALSE)
  }

  text <- paste(readLines(source, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  utils::read.csv(
    text = text,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = "",
    strip.white = TRUE
  )
}

trim_character_columns <- function(data) {
  for (name in names(data)) {
    if (is.character(data[[name]])) {
      data[[name]] <- trimws(data[[name]])
      data[[name]][is.na(data[[name]])] <- ""
    }
  }
  data
}

ensure_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(
      label,
      " is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}

parse_publish <- function(values) {
  raw <- tolower(trimws(as.character(values)))
  raw[is.na(raw)] <- ""

  true_values <- c("true", "t", "1", "yes", "y", "publish", "published", "public", "公開")
  false_values <- c("false", "f", "0", "no", "n", "private", "unpublished", "非公開", "")
  invalid <- !(raw %in% c(true_values, false_values))

  if (any(invalid)) {
    stop(
      "publish contains invalid values: ",
      paste(unique(values[invalid]), collapse = ", "),
      call. = FALSE
    )
  }

  raw %in% true_values
}

parse_number <- function(values, column) {
  raw <- trimws(as.character(values))
  raw[is.na(raw)] <- ""
  out <- suppressWarnings(as.numeric(raw))
  invalid <- nzchar(raw) & is.na(out)

  if (any(invalid)) {
    stop(
      column,
      " contains non-numeric values: ",
      paste(unique(raw[invalid]), collapse = ", "),
      call. = FALSE
    )
  }

  out
}

normalize_species <- function(species) {
  if (is.null(species)) {
    return(NULL)
  }

  ensure_columns(species, "species_jp", "species")
  species <- trim_character_columns(species)

  optional <- c("scientific_name", "family_jp", "marker_color", "description")
  for (name in optional) {
    if (!name %in% names(species)) {
      species[[name]] <- ""
    }
  }

  duplicated_species <- species$species_jp[nzchar(species$species_jp) & duplicated(species$species_jp)]
  if (length(duplicated_species) > 0) {
    stop("species has duplicate species_jp values: ", paste(unique(duplicated_species), collapse = ", "), call. = FALSE)
  }

  invalid_colors <- nzchar(species$marker_color) & !grepl("^#[0-9A-Fa-f]{6}$", species$marker_color)
  if (any(invalid_colors)) {
    stop("species marker_color must be #RRGGBB: ", paste(unique(species$marker_color[invalid_colors]), collapse = ", "), call. = FALSE)
  }

  species
}

assign_default_colors <- function(species_names) {
  unique_species <- sort(unique(species_names[nzchar(species_names)]))
  colors <- default_marker_palette[((seq_along(unique_species) - 1) %% length(default_marker_palette)) + 1]
  names(colors) <- unique_species
  colors
}

normalize_trees <- function(trees, species = NULL) {
  ensure_columns(trees, required_tree_columns, "trees")
  trees <- trim_character_columns(trees)

  trees$lat <- parse_number(trees$lat, "lat")
  trees$lon <- parse_number(trees$lon, "lon")
  trees$accuracy_m <- parse_number(trees$accuracy_m, "accuracy_m")
  trees$publish <- parse_publish(trees$publish)

  if (!"family_jp" %in% names(trees)) {
    trees$family_jp <- ""
  }
  if (!"marker_color" %in% names(trees)) {
    trees$marker_color <- ""
  }

  species <- normalize_species(species)
  if (!is.null(species) && nrow(species) > 0) {
    match_index <- match(trees$species_jp, species$species_jp)
    matched <- !is.na(match_index)

    fill_scientific <- matched & !nzchar(trees$scientific_name)
    trees$scientific_name[fill_scientific] <- species$scientific_name[match_index[fill_scientific]]

    fill_family <- matched & !nzchar(trees$family_jp)
    trees$family_jp[fill_family] <- species$family_jp[match_index[fill_family]]

    fill_color <- matched & !nzchar(trees$marker_color)
    trees$marker_color[fill_color] <- species$marker_color[match_index[fill_color]]
  }

  default_colors <- assign_default_colors(trees$species_jp)
  fill_default_color <- !nzchar(trees$marker_color) & trees$species_jp %in% names(default_colors)
  trees$marker_color[fill_default_color] <- default_colors[trees$species_jp[fill_default_color]]

  trees
}

settings_bounds <- function(settings) {
  env_settings <- list(
    campus_min_lat = env_or_setting("CAMPUS_MIN_LAT", settings, "campus_min_lat"),
    campus_max_lat = env_or_setting("CAMPUS_MAX_LAT", settings, "campus_max_lat"),
    campus_min_lon = env_or_setting("CAMPUS_MIN_LON", settings, "campus_min_lon"),
    campus_max_lon = env_or_setting("CAMPUS_MAX_LON", settings, "campus_max_lon")
  )

  values <- vapply(env_settings, function(value) {
    if (!nzchar(value)) return(NA_real_)
    suppressWarnings(as.numeric(value))
  }, numeric(1))

  if (any(!is.na(values)) && any(is.na(values))) {
    stop("Campus bounds must set all of min/max lat/lon or leave all blank.", call. = FALSE)
  }

  if (all(is.na(values))) {
    return(NULL)
  }

  if (values[["campus_min_lat"]] >= values[["campus_max_lat"]] ||
      values[["campus_min_lon"]] >= values[["campus_max_lon"]]) {
    stop("Campus bounds min values must be smaller than max values.", call. = FALSE)
  }

  values
}

validate_trees <- function(trees, bounds = NULL) {
  published <- trees[trees$publish, , drop = FALSE]

  if (nrow(published) == 0) {
    stop("No rows have publish set to TRUE.", call. = FALSE)
  }

  if (any(!nzchar(published$tree_id))) {
    stop("Published rows must have tree_id.", call. = FALSE)
  }

  duplicated_ids <- published$tree_id[duplicated(published$tree_id)]
  if (length(duplicated_ids) > 0) {
    stop("Published tree_id values must be unique: ", paste(unique(duplicated_ids), collapse = ", "), call. = FALSE)
  }

  if (any(!nzchar(published$species_jp))) {
    stop("Published rows must have species_jp.", call. = FALSE)
  }

  if (any(is.na(published$lat) | is.na(published$lon))) {
    stop("Published rows must have numeric lat and lon.", call. = FALSE)
  }

  out_of_world <- published$lat < -90 | published$lat > 90 | published$lon < -180 | published$lon > 180
  if (any(out_of_world)) {
    stop("Published coordinates must be valid WGS84 latitude/longitude.", call. = FALSE)
  }

  invalid_accuracy <- !is.na(published$accuracy_m) & published$accuracy_m < 0
  if (any(invalid_accuracy)) {
    stop("accuracy_m must be zero or positive.", call. = FALSE)
  }

  date_text <- published$survey_date
  invalid_dates <- nzchar(date_text) & !grepl("^\\d{4}-\\d{2}-\\d{2}$", date_text)
  invalid_dates <- invalid_dates | (nzchar(date_text) & is.na(as.Date(date_text, format = "%Y-%m-%d")))
  if (any(invalid_dates)) {
    stop("survey_date must use YYYY-MM-DD for published rows.", call. = FALSE)
  }

  invalid_colors <- nzchar(published$marker_color) & !grepl("^#[0-9A-Fa-f]{6}$", published$marker_color)
  if (any(invalid_colors)) {
    stop("marker_color must be #RRGGBB.", call. = FALSE)
  }

  if (!is.null(bounds)) {
    outside <- published$lat < bounds[["campus_min_lat"]] |
      published$lat > bounds[["campus_max_lat"]] |
      published$lon < bounds[["campus_min_lon"]] |
      published$lon > bounds[["campus_max_lon"]]

    if (any(outside)) {
      stop(
        "Published coordinates outside campus bounds: ",
        paste(published$tree_id[outside], collapse = ", "),
        call. = FALSE
      )
    }
  } else {
    warning("Campus bounds are not configured; campus-bound coordinate validation was skipped.", call. = FALSE)
  }

  published[, public_tree_columns, drop = FALSE]
}

json_escape <- function(value) {
  value <- as.character(value)
  value[is.na(value)] <- ""
  value <- enc2utf8(value)
  value <- gsub("\\", "\\\\", value, fixed = TRUE)
  value <- gsub("\"", "\\\"", value, fixed = TRUE)
  value <- gsub("\r", "\\r", value, fixed = TRUE)
  value <- gsub("\n", "\\n", value, fixed = TRUE)
  value <- gsub("\t", "\\t", value, fixed = TRUE)
  paste0("\"", value, "\"")
}

json_number <- function(value) {
  if (is.na(value)) {
    return("null")
  }
  format(value, scientific = FALSE, trim = TRUE, digits = 15)
}

json_value <- function(value) {
  if (is.logical(value)) {
    return(ifelse(is.na(value), "null", ifelse(value, "true", "false")))
  }

  if (is.numeric(value)) {
    return(json_number(value))
  }

  json_escape(value)
}

feature_json <- function(row) {
  properties <- public_tree_columns[!public_tree_columns %in% c("lat", "lon")]
  property_json <- vapply(properties, function(name) {
    paste0(json_escape(name), ":", json_value(row[[name]]))
  }, character(1))

  paste0(
    "{\"type\":\"Feature\",\"properties\":{",
    paste(property_json, collapse = ","),
    "},\"geometry\":{\"type\":\"Point\",\"coordinates\":[",
    json_number(row$lon),
    ",",
    json_number(row$lat),
    "]}}"
  )
}

write_geojson <- function(trees, path, source_label) {
  generated_at <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  features <- vapply(seq_len(nrow(trees)), function(index) {
    feature_json(trees[index, , drop = FALSE])
  }, character(1))

  geojson <- paste0(
    "{\n",
    "  \"type\":\"FeatureCollection\",\n",
    "  \"properties\":{",
    "\"generated_at\":", json_escape(generated_at), ",",
    "\"row_count\":", nrow(trees), ",",
    "\"source\":", json_escape(source_label),
    "},\n",
    "  \"features\":[\n    ",
    paste(features, collapse = ",\n    "),
    "\n  ]\n",
    "}\n"
  )

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(geojson), path, useBytes = TRUE)
}

write_public_csv <- function(trees, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    trees,
    path,
    row.names = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
}

