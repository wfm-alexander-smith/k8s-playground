#!/bin/bash

CMD=$0
BASE_DIR=$(cd $(dirname $0) && pwd)
USER=$(id -un)

# COLORS
RED=$(tput -Txterm setaf 1)
GREEN=$(tput -Txterm setaf 2)
YELLOW=$(tput -Txterm setaf 3)
RESET=$(tput -Txterm sgr0)

help () { ## Show help.
  echo -e "\nUsage:\n  ${YELLOW}$0${RESET} ${GREEN}<command> [options]${RESET}\n\nCommands"
  sed -Ene "s/(\w+) \(\) \{ ## (.*)/  ${YELLOW}\1${RESET}:${GREEN}\2${RESET}/p" $0 | column -t -s:
  echo -e "\nOptions:"
  sed -Ene "s/\s*(--\w+)\) (\w+)=.* ## (.*)/  ${YELLOW}\1=\2${RESET}:${GREEN}\3${RESET}/p" $0 | column -t -s:
}

mkenv () { ## Make a new environmet within a cluster.
  if [[ "$#" -lt 2 ]]; then
    echo "You must provide an environment name as as argument."
    exit 1
  fi

  env_dir=${BASE_DIR}/terraform/aws-accounts/${ACCOUNT}/clusters/${CLUSTER:-${ACCOUNT}}/environments/${2}
  if [[ -e "$env_dir" ]]; then
    echo "The directory $env_dir already exists."
    exit 1
  fi

  set -e
  mkdir ${env_dir}

  if [[ -n "$APP" ]]; then
    rsync -av --exclude='.*/' --exclude="apps" ${BASE_DIR}/terraform/aws-accounts/development/clusters/development/environments/dev/ ${env_dir}/
    mkdir ${env_dir}/apps
    rsync -av --exclude='.*/' ${BASE_DIR}/terraform/aws-accounts/development/clusters/development/environments/dev/apps/${APP} ${env_dir}/apps
  else
    rsync -av --exclude='.*/' ${BASE_DIR}/terraform/aws-accounts/development/clusters/development/environments/dev/ ${env_dir}/
  fi
  sed -i 's/"dev"/"'$2'"/' ${env_dir}/environment.tfvars
  find ${env_dir}/ -name '*.tfvars' -print -exec sed -i 's/"\(.*\)dev\(\..*\)"/"\1'${2}'\2"/' {} \;
  echo -e "\n${GREEN}Environment created in${RESET}"
  echo -e "  ${YELLOW}${env_dir}${RESET}"
  echo -e "${GREEN}You may now make any additional edits to the files in that directory.${RESET}\n"
  echo -e "${GREEN}See the README for information on what needs to done next.${RESET}"
}

build () { ## Build docker image locally.
  docker build -f ${BASE_DIR}/terraform/Dockerfile -t terraform-tools ${BASE_DIR}
}

ensure_image () {
  if [[ -z "$(docker images -q terraform-tools)" ]]; then
    echo "${YELLOW}No terraform-tools image found, building now.${RESET}"
    build
  fi
}

set_run_in () {
  if [[ -n "${APP}" ]]; then
    if [[ -z "${ENV}" ]]; then
      echo "${RED}You must set ENV when you set APP.${RESET}"
      help
      exit 1
    fi
    RUN_IN="${RUN_IN}/clusters/${CLUSTER:-${ACCOUNT}}/environments/${ENV}/apps/${APP}"
  elif [[ -n "${ENV}" ]]; then
    RUN_IN="${RUN_IN}/clusters/${CLUSTER:-${ACCOUNT}}/environments/${ENV}"
  elif [[ -n "${CLUSTER}" ]]; then
    RUN_IN="${RUN_IN}/clusters/${CLUSTER}"
  fi
  echo "${YELLOW}Running in:${RESET} ${GREEN}$RUN_IN${RESET}"
}

tg () { ## Run the specified terragrunt command.
  ensure_image
  shift
  mkdir -p ${HOME}/.aws # Ensure aws config dir exists
  mkdir -p ${HOME}/.helm # Ensure helm config dir exists
  set_run_in

  set -x
  docker run -it --rm --user $(id -u):$(id -g) \
    --mount type=bind,source="${BASE_DIR}",target=/tf/aws-infrastructure \
    --mount type=bind,source="${HOME}/.aws",target=/tf/.aws \
    --mount type=bind,source="${HOME}/.helm",target=/tf/.helm \
    terraform-tools -c "cd /tf/${RUN_IN} && helm init --client-only && terragrunt $*"
}

host_ip () { ## Print Terraform host IP.
  aws --region ${AWS_REGION} --profile ${AWS_PROFILE} \
    ec2 describe-instances \
    --filters Name=tag:Application,Values=terraform \
              Name=instance-state-name,Values=running \
              Name=tag:Account,Values=${ACCOUNT} \
    --query 'Reservations[*].Instances[*].PublicIpAddress' --output text | head -n 1
}

helm_up () { ## Run `helm repo update`.
  ensure_image
  docker run -it --rm --user $(id -u):$(id -g) \
    --mount type=bind,source="${BASE_DIR}",target=/tf/aws-infrastructure \
    --mount type=bind,source="${HOME}/.aws",target=/tf/.aws \
    --mount type=bind,source="${HOME}/.helm",target=/tf/.helm \
    terraform-tools -c "cd /tf && helm repo update"
}

sync () { ## Sync terraform modules and configs up to terraform server.
  ssh_cmd mkdir -p ${USER}
  rsync -avz --delete --exclude='.*/' ${BASE_DIR}/ ec2-user@$(host_ip):${USER}/aws-infrastructure/
}

clean () { ## Delete temporary files created by terragrunt and terraform.
  find ${BASE_DIR} -name .terragrunt-cache -print -exec rm -rf {} \;
  find ${BASE_DIR} -name .terraform -print -exec rm -rf {} \;
}

ssh_cmd () {
  set_run_in
  echo ssh ec2-user@$(host_ip) -t $@
  ssh ec2-user@$(host_ip) -t $@
}

shell () { ## Run a shell in the terraform docker container.
  ensure_image
  docker run -it --rm --user $(id -u):$(id -g) \
    --mount type=bind,source="${BASE_DIR}",target=/tf/aws-infrastructure \
    --mount type=bind,source="${HOME}/.aws",target=/tf/.aws \
    --mount type=bind,source="${HOME}/.helm",target=/tf/.helm \
    terraform-tools -c "cd /tf && exec bash"
}

remote () { ## Run a command from this script on the terraform server.
  sync
  ssh_cmd ${USER}/aws-infrastructure/tg.sh $(echo "$OPTS" | sed "s/'remote'//")
}


# Parse options, set env vars from them
LONGOPTS="$(sed -Ene "s/\s*--((\w|-)+)\) (\w+)=.* ## (.*)/\1:/p" $0 | tr -t '\n' ',')"
OPTS=$(getopt --name="$(basename "$0")" -o '' --longoptions "${LONGOPTS}" -- "$@")
eval set -- $OPTS

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) AWS_REGION="$2" ## AWS Region to search for the Terraform server (defaults to "us-west-2").
      shift 2 ;;
    --profile) AWS_PROFILE="$2" ## Profile from ~/.aws/credentials to use for AWS API calls (defaults to "glidecloud-$ACCOUNT").
      shift 2 ;;
    --account) ACCOUNT="$2" ## Account in aws-accounts directory to run command in (defaults to "development").
      shift 2 ;;
    --cluster) CLUSTER="$2" ## Cluster to run terragrunt command on (defaults to same as ACCOUNT).
      shift 2 ;;
    --env) ENV="$2" ## Environment to run terragrunt command on.
      shift 2 ;;
    --app) APP="$2" ## App to run terragrunt command on (requires ENV to be set as well).
      shift 2 ;;
    --run-in) RUN_IN="$2" ## Directory under aws-infrastructure to run terragrunt in (overrides ACCOUNT, APP, ENV, CLUSTER opts).
      shift 2 ;;
    --) shift ; break ;;
    *) echo "${RED}SOMETHING BROKE $1${RESET}" ; exit 1 ;;
  esac
done

# Defaults
: ${AWS_REGION:=us-west-2}
: ${ACCOUNT:=development}
: ${AWS_PROFILE:=glidecloud-${ACCOUNT}}
: ${RUN_IN:=aws-infrastructure/terraform/aws-accounts/${ACCOUNT}/${TF_DIR}}

if [[ -z "$(sed -Ene "s/(\w+) \(\) \{ ## (.*)/\1/p" $0 | grep "^$1$")" ]]; then
  echo "Unrecognized command ${RED}$1${RESET}"
  help
else
  echo $@
  $1 $@
fi
