source("scripts/tree_data_lib.R", encoding = "UTF-8")

expect_error <- function(expr, pattern) {
  expr <- substitute(expr)
  matched <- FALSE
  message <- NULL

  tryCatch(
    eval(expr, parent.frame()),
    error = function(error) {
      message <<- conditionMessage(error)
      matched <<- grepl(pattern, message)
    }
  )

  if (!matched) {
    stop("Expected error matching `", pattern, "`, got: ", message %||% "no error", call. = FALSE)
  }
}

`%||%` <- function(lhs, rhs) {
  if (is.null(lhs)) rhs else lhs
}

base_species <- data.frame(
  species_jp = c("イチョウ", "クスノキ"),
  scientific_name = c("Ginkgo biloba", "Cinnamomum camphora"),
  family_jp = c("イチョウ科", "クスノキ科"),
  marker_color = c("#c28b19", "#1f7a5a"),
  stringsAsFactors = FALSE
)

base_trees <- data.frame(
  tree_id = c("T-0001", "T-0002"),
  lat = c("35.71020", "35.71048"),
  lon = c("139.76120", "139.76172"),
  species_jp = c("イチョウ", "クスノキ"),
  scientific_name = c("", "Cinnamomum camphora"),
  survey_date = c("2026-06-11", "2026-06-11"),
  observer = c("field-team", "field-team"),
  accuracy_m = c("3", "4"),
  publish = c("true", "TRUE"),
  note_public = c("正門付近", "講義棟前"),
  stringsAsFactors = FALSE
)

bounds <- c(
  campus_min_lat = 35.70,
  campus_max_lat = 35.72,
  campus_min_lon = 139.75,
  campus_max_lon = 139.77
)

normalized <- normalize_trees(base_trees, base_species)
public <- validate_trees(normalized, bounds)
stopifnot(nrow(public) == 2)
stopifnot(public$scientific_name[1] == "Ginkgo biloba")

duplicate_trees <- base_trees
duplicate_trees$tree_id[2] <- "T-0001"
expect_error(
  validate_trees(normalize_trees(duplicate_trees, base_species), bounds),
  "unique"
)

missing_species <- base_trees
missing_species$species_jp[1] <- ""
expect_error(
  validate_trees(normalize_trees(missing_species, base_species), bounds),
  "species_jp"
)

bad_coordinate <- base_trees
bad_coordinate$lat[1] <- "not-a-number"
expect_error(
  normalize_trees(bad_coordinate, base_species),
  "non-numeric"
)

outside_campus <- base_trees
outside_campus$lon[1] <- "140.00000"
expect_error(
  validate_trees(normalize_trees(outside_campus, base_species), bounds),
  "outside campus bounds"
)

bad_date <- base_trees
bad_date$survey_date[1] <- "2026/06/11"
expect_error(
  validate_trees(normalize_trees(bad_date, base_species), bounds),
  "YYYY-MM-DD"
)

message("Validation tests passed.")

