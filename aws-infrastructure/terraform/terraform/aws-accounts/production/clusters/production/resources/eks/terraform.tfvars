terragrunt = {
  terraform {
    source = "${find_in_parent_folders("modules")}//eks"
  }

  dependencies {
    paths = [
      "../../../../resources/mgmt-vpc",
      "../vpc",
    ]
  }

  include = {
    path = "${find_in_parent_folders()}"
  }
}
