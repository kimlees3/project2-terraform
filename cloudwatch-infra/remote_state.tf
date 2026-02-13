data "terraform_remote_state" "dr_vpc" {
  backend = "local"
  config = {
    path = "../VPC/terraform.tfstate"
  }
}
