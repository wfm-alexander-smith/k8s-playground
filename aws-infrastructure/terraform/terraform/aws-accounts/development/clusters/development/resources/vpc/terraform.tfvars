terragrunt = {
  terraform {
    source = "${find_in_parent_folders("modules")}//vpc"
  }

  dependencies {
    paths = ["../../../../resources/mgmt-vpc"]
  }

  include = {
    path = "${find_in_parent_folders()}"
  }
}
