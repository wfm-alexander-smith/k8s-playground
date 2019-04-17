terragrunt = {
  terraform {
    source = "${find_in_parent_folders("modules")}//cluster"
  }

  dependencies {
    paths = [
      "../../../../resources/mgmt-vpc",
      "../vpc",
      "../eks",
    ]
  }

  include = {
    path = "${find_in_parent_folders()}"
  }
}
