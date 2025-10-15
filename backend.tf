terraform {
  backend "gcs" {
    bucket = "my-terraform-state-chatverse-475212"
    prefix = "infra"
  }
}
