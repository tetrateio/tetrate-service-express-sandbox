#!/usr/bin/env bash

export ROOT_DIR="$(
	cd -- "$(dirname "${0}")" >/dev/null 2>&1
	pwd -P
)"
source ${ROOT_DIR}/variables.sh

export ACTION=${1}

if [[ ${ACTION} = "describe" ]]; then
	source ${ROOT_DIR}/describe.sh demo
fi

init_kubeconfig() {
  local index="$1"
  local cluster_name="$2"
  local region="$3"
  command="eksctl utils write-kubeconfig --cluster ${cluster_name} --region ${region} --kubeconfig .kube/config"
  (    
    run_command_at_jumpbox $index $command
  )
}

deploy_action() {
  local action_name="${1}"
  local url_suffix="${2}"
  local script_name="${3}"
  local cluster_name="${4}"
  local external_dns_zone="${5}"
  print_info "${action_name}... as per https://docs.tetrate.io/service-express/getting-started/${url_suffix}"
  export index=0
  export AWS_K8S_CLUSTERS=$(echo ${TFVARS} | jq -c ".k8s_clusters.aws")
  cluster_name=$(echo $AWS_K8S_CLUSTERS | jq -cr '.['$index'].name')
  region=$(echo $AWS_K8S_CLUSTERS | jq -cr '.['$index'].region')
  k8s_version=$(echo $AWS_K8S_CLUSTERS | jq -cr '.['$index'].version')
  if [[ "$cluster_name" == "null" ]]; then
    cluster_name=$NAME_PREFIX-$index-$region
  fi
  init_kubeconfig $index $cluster_name $region
  run_command_at_jumpbox "$index" "if [ ! -d demo ]; then git clone ${GIT_REPO}; cp -r tetrate-service-express-sandbox/demo . ;fi"
  run_command_at_jumpbox "$index" "./demo/scripts/getting_started_guide/${script_name}" "$cluster_name" "$external_dns_zone"
}

case "${ACTION}" in
  describe) source "${ROOT_DIR}/describe.sh" demo ;;
  deploy-application | 01-deploy-application | 01)
    deploy_action "Deploying application" "deploy-application" "01-deploy-application.sh"
    ;;
  mtls | 02-mtls | 02)
    deploy_action "Enforce Encryption with Mutual TLS" "mtls" "02-mtls.sh"
    ;;
  zero-trust | 03-zero-trust | 03)
    deploy_action "Enforce A Zero-Trust Security Policy" "zero-trust" "03-zero-trust.sh"
    ;;
  publish-service | 04-publish-service | 04)
    if [[ "$external_dns_zone" = "null" ]]; then
      deploy_action "Publishing a Service" "publish-service" "04-publish-service.sh"
    else
      deploy_action "Publishing a Service via AWS Route53" "publish-service" "04-r53-publish-service.sh" "$cluster_name" "$external_dns_zone"
    fi
    ;;
  publish-api | 05-publish-api | 05)
    deploy_action "Publishing an API from the OAS definition" "publish-api" "05-publish-api.sh"
    ;;
esac