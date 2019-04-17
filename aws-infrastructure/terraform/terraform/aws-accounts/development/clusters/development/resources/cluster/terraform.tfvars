terragrunt = {
  terraform {
    source = "${find_in_parent_folders("modules")}//cluster"
  }

  dependencies {
    paths = ["../../../../resources/mgmt-vpc"]
  }

  include = {
    path = "${find_in_parent_folders()}"
  }
}
