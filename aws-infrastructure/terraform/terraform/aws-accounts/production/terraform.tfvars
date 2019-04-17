terragrunt = {
  # Configure Terragrunt to automatically store tfstate files in an S3 bucket
  remote_state {
    backend = "s3"

    config {
      encrypt        = true
      region         = "us-east-1"
      bucket         = "glidecloud-terraform-production"
      key            = "${path_relative_to_include()}/terraform.tfstate"
      dynamodb_table = "terraform-locks-production"
      profile        = "glidecloud-production"
    }
  }

  # Configure root level variables that all resources can inherit
  terraform {
    extra_arguments "account_env" {
      commands = ["${get_terraform_commands_that_need_vars()}"]

      optional_var_files = [
        "${get_tfvars_dir()}/${find_in_parent_folders("account.tfvars", "ignore")}",
        "${get_tfvars_dir()}/${find_in_parent_folders("cluster.tfvars", "ignore")}",
        "${get_tfvars_dir()}/${find_in_parent_folders("environment.tfvars", "ignore")}",
        "${get_tfvars_dir()}/${find_in_parent_folders("app.tfvars", "ignore")}",
      ]
    }
  }
}
