terraform {
  backend "s3" {
    bucket                      = "tfstate"
    key                         = "apps/terraform.tfstate"
    region                      = "us-east-1"
    endpoints                   = { s3 = "http://localhost:9000" }
    use_path_style              = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
  }
}
