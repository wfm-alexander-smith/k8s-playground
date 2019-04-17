# Terragrunt

The configs in this repo is intended to be used with
[terragrunt](https://github.com/gruntwork-io/terragrunt), which is a thin
wrapper around terraform which makes some common patterns easier. You will want
to read through the terragrunt docs before working with this repo.

# Resource hierarchy

Resources created by the Terraform configs in this repo are organized into the
following hierarchy:

- AWS Accounts
  - Clusters
    - Environments
      - Applications

Each level in the hierarchy has configurations specific to that level and/or
resources specific to that level. Nested configurations reference both variables
and resources created at higher levels. The directory structure inside the
`terraform` directory mirrors the hierarchy.

For example, the file
`/terraform/aws-accounts/development/clusters/development/environments/dev/apps/h-cs-sp6/terraform.tfvars`
contains the configuration for the "dev" Environment Service Point 6 application
on the "development" cluster on the "development" AWS Account, which uses
variables defined in that file as well as ones defined in:

- `/terraform/aws-accounts/development/clusters/development/environments/dev/environment.tfvars`
- `/terraform/aws-accounts/development/clusters/development/cluster.tfvars`
- `/terraform/aws-accounts/development/account.tfvars`
- `/terraform/aws-accounts/development/terraform.tfvars` (which is where the main Terragrunt config for the AWS Account lives)

It also references the VPC and EKS cluster created by
`/terraform/aws-accounts/development/clusters/development/resources/cluster/terraform.tfvars`
which reference the management VPC created by
`/terraform/aws-accounts/development/resources/mgmt-vpc/terraform.tfvars`

Each of these `terraform.tfvars` files (except for the top-level ones in each
AWS Account), references a module from the `terraform/modules` directory and
contains the variables needed by that module and/or inherits them from the app,
environment, cluster, or aws-account config which it is nested in.

The modules also use sub-modules which split the management of resources up
into smaller chunks.

# Developer setup

## AWS Credentials

Each aws-account defines an `aws_profile` value which is used to tell
Terraform/Terragrunt which AWS account to use to perform its tasks. In the final
production configuration, the production account will be separate from the
development account.

The profile specified will be loaded from your `~/.aws/credentials` file. If you
don't have the necessary profile, you can add it by running `aws configure
--profile={profile-name-here}`, or if you have your credentials under the
default profile already, edit "~/.aws/credentials" and either rename the default
profile or copy it to a new profile with the appropriate name.

The two profiles currently needed are `glidecloud-development` and
`glidecloud-production` (and you only need both if you are going to be deploying
to both accounts).

## Using the helper script `tg.sh`

Rather than installing all of the dependencies as described below, you should
probably use the helper script `tg.sh` instead.

Some of the terraform modules depend on being able to access databases within
the cluster VPC, which is in a private subnet. In order to accomplish this, a
`terraform` EC2 instance is started in the management VPC. The helper script can
run commands either locally or from the terraform instance.

### `tg.sh` Dependencies

To run the script you will need, at a minimum, `bash`, `ssh`, `rsync`, and the
[AWS CLI](https://aws.amazon.com/cli/) installed. If you are going to run it
locally (to create a new management VPC, for example), you will also need
docker. It's likely that the script will only run properly from Linux, so you
will probably want to be running a VM if you aren't running Linux on your
machine.

### `tg.sh` usage

Running `./tg.sh help` will print out a list of commands and options.

The primary commands used will be `tg` and `remote`.

The `tg` command will change into a specified directory and run the specified
terragrunt command. If no options are specified, the directory it will run in is
terraform/aws-accounts/development. The `--account`, `--cluster`, `--env`, and
`--app` options can be used to specify different directories in which to run
terragrunt. Most can be left out and will default to not being set, which means
terragrunt will run in a higher-level directory.

Examples:

```
$ ./tg.sh tg plan-all # `terragrunt plan-all` in `aws-accounts/development`

$ ./tg.sh --account development/resources/mgmt-vpc tg plan # `terragrunt plan` in `aws-accounts/development/resources/mgmt-vpc`

$ ./tg.sh --cluster development/resources/cluster tg apply # `terragrunt apply` in `aws-accounts/development/clusters/development/resources/cluster`

$ ./tg.sh --env qa tg plan-all # `terragrunt plan-all` in `aws-accounts/development/clusters/development/environments/qa`

$ ./tg.sh --env dev --app h-cs-sp6 tg plan # `terragrunt plan` in `aws-accounts/development/clusters/development/environments/dev/apps/h-cs-sp6`
```

The `remote` command uses SSH to run the specified command on the terraform EC2
instance within the management VPC. Just prefix any command with `remote` and it
will be run there instead of locally.

### `./tg.sh mkenv`

You can create a new environment with `tg.sh` with the `mkenv` command. It takes
one positional argument which is the name of the new environment, and it will
use the `--account` and `--cluster` arguments if specified to determine which
account and cluster the new envrionment will go into (account defaults to
"development" and cluster defaults to whatever account is). It copies the `dev`
environment from the development cluster in the development account.

If you provide the `--app` option, it will only copy the specified app into the
new environment, rather than all of the apps in the `dev` environment.

After you run the command, you will possibly need to edit the copied files. They
will already be updated to replace "dev" in several values with your new
environment name.

If you want your new environment to have unique domain names, you will need to
create hosted zones in Route53 within the account where the environment will be
deployed and if you want those domains to actually be routed to your environment,
you'll need to add NS records to the root DNS zone for the base domain. If you
wish to just use the dev environment's hosted zone, you will need to change the
root domain settings back to what they were in the dev environment
("dev.glidecloud.io", "dev.glidecloud.com", "accounts-dev.glidecloud.io" for
"glidecloud", and "glidecloud-common", respectively).

There are several per-environment parameters which are read from the AWS
Parameter Store which will need to be set before your new environment will
deploy properly (replace "C" and "E" with the cluster and environment names,
respectively).

path                                    | type         | description
----------------------------------------|--------------|------------------------------------------------
/C/E/caretend/auth/default_security_key | SecureString | The default security key used by Atlas
/C/E/glidecloud-common/smtp/username    | String       | AWS Key for Atlas auth server to send emails.
/C/E/glidecloud-common/smtp/password    | SecureString | AWS Secret for Atlas auth server to send emails
/C/E/glidecloud-common/smtp/error/email | String       | Email which errors should be sent to.

For environments in the development account, these settings can usually just be
copied from the parameters for the dev cluster.

## Kubernetes Dashboard

The Kubernetes Dashboard is deployed as part of the cluster. Once it has been
deployed, you can access it with the following steps.

1. Generate an auth token by running
   ```
   $ AWS_PROFILE=glidecloud-development aws-iam-authenticator token -i development
   ```
   (replace both instances of "development" with whichever cluster you are going to be accessing)
2. Copy the resulting token.
3. Run `kubectl proxy`
4. Open http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/ in your browser
5. Click "Token", paste in the token you copied earlier, click "Log In"
6. Use the dashboard (note that the token will expire after 15 minutes, so you'll need to generate another and log back in after that).

## Dependencies

Follow each of the links below to install each dependency.

Dependency               | Description
-------------------------|-------------------------------------------------------------------------
[Terraform]              | The actual tool doing infrastructure provisioning.
[Terragrunt]             | A wrapper around Terraform which adds some conveniences.
[jq]                     | A command-line tool for manipulating JSON (used in some scripts).
[kubectl]                | The Kubernetes command-line tool.
[aws-iam-authenticator]  | Used to authenticate with the EKS cluster.
[terraform-provider-k8s] | A terraform plugin which allows creating arbitrary Kubernetes resources.

[terraform]: https://www.terraform.io/intro/getting-started/install.html#installing-terraform "Install Terraform"
[terragrunt]: https://github.com/gruntwork-io/terragrunt#install-terragrunt "Install Terragrunt"
[jq]: https://stedolan.github.io/jq/download/ "Install jq"
[kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/ "Install kubectl"
[aws-iam-authenticator]: https://docs.aws.amazon.com/eks/latest/userguide/configure-kubectl.html "Install aws-iam-authenticator"
[terraform-provider-k8s]: https://github.com/ericchiang/terraform-provider-k8s#usage "Install terraform-provider-k8s"

## Running Terragrunt

Aside from initial creation of a new cluster or cluster-wide incremental
updates, it's likely that you'll not want to run terragrunt commands at the
aws-account or cluster level.

When working on a single config, it usually makes more sense to `cd` into the
directory of that specific config (like
`/terraform/aws-accounts/development/clusters/development/environments/dev/apps/h-cs-sp6/db/`
from the example above), and just run `terragrunt plan` and `terragrunt apply`.
Not only does this make you less likely to accidentally change extra resources,
but it will also be faster since it won't be checking the state of every
resource along the way.

You will almost never want to run `terragrunt destroy-all` unless you are
literally trying to remove an entire cluster, and even then, it is likely that
the cluster will not cleanly destroy in a single run (because resources will be
created dynamically by the running Kubernetes cluster and prevent terraform from
being able to remove some things like security groups and VPCs). If you need to
destroy an entire cluster, there may be some extra work manually deleting some
dynamically-created resources and then `cd`ing into specific configuration
directories and running `terragrunt destroy` individually.

## Creating a new environment, cluster, or AWS account

For testing or development purposes, you may want to create a new separate environment, cluster, or "AWS account".

### Creating a new environment

(See the section `./tg.sh mkenv` above for a slightly more automated way of doing this)

Here's how to do that (with "yourenv" as an example name for the new environment):

- Copy `terraform/aws-accounts/development/clusters/development/environments/dev` to `terraform/aws-accounts/development/clusters/development/environments/yourenv`
- Edit `terraform/aws-accounts/development/clusters/development/environments/yourenv/environment.tfvars` and change the `env` setting to the name of your new environment ("yourenv" in this example).
- Change to the `terraform/aws-accounts/development/clusters/development/environments/yourenv` directory and run `terragrunt plan-all` to see the plan for creating the environment (it may ask if it's ok for it to run configs above the current directory, respond "n" to this when it asks).
- Run `terragrunt apply-all` and respond with "y" when asked to build the environment.
- To tear down an environment, run `terragrunt destroy-all` (making sure you are in the `yourenv` directory as above), and **make sure to respond "n" when asked if higher-level dependency configs should also be run** and then respond "y" when asked if you want to run destroy in the list of direcotires (ensure it only includes ones in `yourenv`). Be sure you really want to do that before doing so (if you're in the dev or prod directory, you probably don't want to do that).

### Creating a new cluster

The process for making your own cluster is similar:
- Copy `terraform/aws-accounts/development/clusters/development` to `terraform/aws-accounts/development/clusters/yourcluster`
- Edit `terraform/aws-accounts/development/clusters/yourcluster/cluster.tfvars` with `cluster = "yourcluster"` and any customizations on the cluster workers you want.
- Add/remove/customize any environments inside your new cluster.
- Run `terragrunt apply-all` in your cluster directory.
- For a cluster, destroy it with `terragrunt destroy-all` within the cluster directory. Again, say "n" when asked if you also want it to manage the `mgmt-vpc` config, since that is outside the scope of a given cluster, and **only run destroy-all if you are sure you want do destroy everything in that cluster.**

### Creating a new "AWS Account"

- Copy `terraform/aws-accounts/development` to `terraform/aws-accounts/myaccount`.
- Edit `terraform/aws-accounts/myaccount/account.tfvars` and `terraform/aws-accounts/myaccount/terraform.tfvars` with a different aws_profile, tfstate_bucket, and tfstate_lock_table (S3 buckets are global so they can't be reused even on separate AWS root accounts, the lock table needs to be different if you are actually using the same AWS root account for your new "account", and the profile needs to be different if you are using a separate AWS root account).
- Edit `terraform/aws-accounts/myaccount/resources/mgmt-vpc/terraform.tfvars` to add in any SSH public keys which will be needed to SSH into the account's bastion node. Optionally, you can also change the CIDR block which will be used by the management VPC.
- Rename `terraform/aws-accounts/myaccount/clusters/development` to `terraform/aws-accounts/myaccount/clusters/mycluster` (or whatever name you want for it).
- Edit `terraform/aws-accounts/myaccount/clusters/mycluster/cluster.tfvars`, changing the `cluster` variable to `mycluster` (or whatever you renamed the directory to), and changing any other variables needed like the type or number of workers or the cluster VPC CIDR block.
- Edit `terraform/aws-accounts/myaccount/clusters/mycluster/resources/cluster/terraform.tfvars`, changing the `qlik_root_domain` setting to a different domain.
- Rename and/or remove the `dev` and `qa` directories from `terraform/aws-accounts/development/clusters/development/environments` (for example `terraform/aws-accounts/development/clusters/development/environments/myenv`).
- Edit any `environment.tfvars` files from the above directories to set the `env` variable to the new name chosen (i.e. "myenv").
- Edit `terraform/aws-accounts/myaccount/clusters/mycluster/environments/myenv/apps/h-cs-sp6/terraform.tfvars` to have a different `root_domain` setting (you will also need to manually create a Route53 Hosted Zone and point the NS records that go along with this if you want DNS configuration to actually work), as well as any other settings desired.

# Pinning modules

By default, configs in the `terraform/aws-accounts` sub-directory refer to their
modules via relative paths, but if a given account or environment needs to have
its modules pinned to an older version for any reason, that can be done.

Change the source parameter from the current form:

```
terragrunt = {
  terraform {
    source = "${find_in_parent_folders("modules")}//mgmt-vpc"
  }
  ...
}
```

into a reference to the git repo:

```
terragrunt = {
  terraform {
    source = "git::ssh://git@github.com/glidecloud/aws-infrastructure.git//terraform/modules/mgmt-vpc?ref=GIT_REF"
  }
  ...
}
```

replacing `GIT_REF` with the appropriate tag, branch, or commit.

After doing this, terragrunt will pull down and run that specific version instead of the current checked-out version. Note: you will also need to have git configured to [work via SSH for GitHub](https://help.github.com/articles/connecting-to-github-with-ssh/) for this to work properly.

# Kubernetes Authentication

EKS gives admin-level access to the user which creates a given cluster, and uses
[aws-iam-authenticator] for all other authentication. It uses a Kubernetes
ConfigMap to configure mapping between AWS IAM users and Kubernetes users and
groups.

The clusters created by this repo have their auth config created by
[eks/auth.tf], which creates IAM Roles with the naming scheme `k8s-CLUSTER-ROLE`
(where CLUSTER is the cluster name and ROLE is one of the values from
`roles_to_map` at the top of `auth.tf`) which are mapped them to a series of
Kubernetes groups, and also creates a series of IAM Policies with the same names
which can be attached to IAM groups or users to give them the ability to assume
that role.

In order for a user other than the one who created the EKS cluster to be able to use kubectl to talk to the cluster, they will need to:

1. Be attached to one of the IAM Policies mentioned above, most likely by being in an IAM group with the policy attached. For example, on the development account, the group `KubernetesAdmins` has the `k8s-development-admin` policy attached to it, which allows assuming the `k8s-development-admin` IAM Role, which is mapped to the `system:masters` group in the development EKS cluster, allowing users who assume that role full admin access to the cluster.
2. Ensure they have aws-iam-authenticator installed (see link above).
3. Create a `~/.kube/config` file like this:
    ```
    apiVersion: v1
    clusters:
    - cluster:
        server: https://XXXXXXXXXXX.eks.amazonaws.com # Get these values from cluster on AWS console
        certificate-authority-data: CA_CERT_HERE
      name: kubernetes
    contexts:
    - context:
        cluster: kubernetes
        user: aws
      name: aws
    current-context: aws
    kind: Config
    preferences: {}
    users:
    - name: aws
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1alpha1
          command: aws-iam-authenticator
          env:
          - name: "AWS_PROFILE"
            value: "glidecloud-development" # Or other appropriate profile from ~/.aws/credentials
          args:
            - "token"
            - "-i"
            - "development" # Or appropriate cluster name here
            - "-r"
            - "k8s-development-admin" # Or whichever role they are allowed to assume

    ```

The base kubeconfig can be acquired from terraform by changing to the
`resouces/cluster` directory in the account/cluster of choice and running
`terragrunt output kubeconfig`. If it is going to be used by a user other than
the one who initially created the cluster, the extra role argument (the last 2
lines in the example above) will need to be added.

[aws-iam-authenticator]: https://github.com/kubernetes-sigs/aws-iam-authenticator
[eks/auth.tf]: /terraform/modules/eks/auth.tf
# `terraform fmt`

The Terraform files in this repo are formatted using the `terraform fmt`
command. Your editor may have a plugin to support automatically formatting them,
or you can alternatively just run `terraform fmt` from the commandline.

# AWS Tagged Resources
Most resources created by these scripts are tagged with the following
descriptions and tag names:
   Description       AWS Tag
   ---------------   -----------------------
   Hosting Account   aws_tag_hosting_account
   Team              aws_tag_team
   Customer          aws_tag_customer
   Cost Center       aws_tag_cost_center
   --------------------------------------------------------------------------

   Explanation
   --------------------------------------------------------------------------
   Hosting Account
      This is the AWS account hosting the environment; awsrootsp6prod.

   Team
      The team responsible for the tagged resource.

   Customer
      Customer name if targeted for a specific customer.

   Cost Center
      Business unit of specific customer.
   --------------------------------------------------------------------------

   Additional modifications
   --------------------------------------------------------------------------
   To add, modify, or remove existing tags, you will need to modify each
   module affected, listed below.
      aws-infrastructure/terraform/
        aws-accounts/development/account.tfvars
        aws-accounts/production/account.tfvars
        modules/
          app-bucket/main.tf
          app-bucket/variables.tf
          cluster/main.tf
          cluster/variables.tf
          eks/cluster.tf
          eks/variables.tf
          eks/workers.tf
          h-cs-sp6/main.tf
          h-cs-sp6/variables.tf
          ingress-controller/main.tf
          ingress-controller/variables.tf
          mgmt-vpc/main.tf
          mgmt-vpc/variables.tf
          qlik/lb.tf
          qlik/main.tf
          qlik/nodes.tf
          qlik/proxy.tf
          qlik/variables.tf
          rds/main.tf
          rds/variables.tf
          redis/main.tf
          redis/variables.tf
          vpc/main.tf
          vpc/variables.tf
          website-bucket/main.tf
          website-bucket/variables.tf
   --------------------------------------------------------------------------
