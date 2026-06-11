source("scripts/tree_data_lib.R", encoding = "UTF-8")

main <- function() {
  settings <- read_settings()

  trees_source <- env_or_setting(
    "TREES_CSV_URL",
    settings,
    "source_csv_url",
    setting_value(settings, "sample_csv", "data/source/sample_trees.csv")
  )

  species_source <- env_or_setting(
    "SPECIES_CSV_URL",
    settings,
    "species_csv_url",
    setting_value(settings, "sample_species_csv", "")
  )

  output_csv <- setting_value(settings, "output_csv", "data/public/trees.csv")
  output_geojson <- setting_value(settings, "output_geojson", "data/public/trees.geojson")

  species <- NULL
  if (nzchar(species_source)) {
    species <- read_csv_source(species_source)
  }

  trees <- read_csv_source(trees_source)
  normalized <- normalize_trees(trees, species)
  public <- validate_trees(normalized, settings_bounds(settings))

  write_public_csv(public, output_csv)
  write_geojson(public, output_geojson, trees_source)

  message("Wrote ", nrow(public), " public tree rows.")
  message("CSV: ", output_csv)
  message("GeoJSON: ", output_geojson)
}

main()

