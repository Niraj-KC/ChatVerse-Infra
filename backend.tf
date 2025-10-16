terraform {
  backend "gcs" {
    bucket = "my-terraform-state-chatverse-475306"
    prefix = "infra"
  }
}
