locals {
  region            = "asia-northeast1"
  billing_key_value = "flights"

  bq_data_science_dataset_name = "dsongcp"
  bq_raw_data_tbl_name         = "flights_raw"

  ingest_flights_monthly_req_body = {
    bucket           = google_storage_bucket.staging.name
    dest_bq_tbl_fqdn = "${local.bq_data_science_dataset_name}.${local.bq_raw_data_tbl_name}"
  }
}