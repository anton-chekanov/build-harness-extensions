#!/usr/bin/env bash
#
# Helper script to start k3d
#
# Also adds a docker-registry and an ingress to aid local development
#
# See https://k3d.io/
#
set -o errexit

[ "$TRACE" ] && set -x

K3D_K8S_IMAGE=${K3D_K8S_IMAGE:-"rancher/k3s:v1.20.4-k3s1"}
K3D_CLUSTER_NAME=${K3D_CLUSTER_NAME:-"local"}
K3D_DOCKER_REGISTRY_NAME=${K3D_DOCKER_REGISTRY_NAME:-"registry.localhost"}
K3D_DOCKER_REGISTRY_PORT=${K3D_DOCKER_REGISTRY_PORT:-5000}
K3D_INSTALL_DOCKER_REGISTRY=${K3D_INSTALL_DOCKER_REGISTRY:-"true"}
K3D_INSTALL_LB=${K3D_INSTALL_LB:-"true"}
K3D_WAIT=${K3D_WAIT:-"120s"}
K3D_API_SERVER_ADDRESS=${K3D_API_SERVER_ADDRESS:-"0.0.0.0"}
K3D_API_SERVER_PORT=${K3D_API_SERVER_PORT:-6443}

## Create a cluster with the local registry enabled in container
create() {

  if [ "$(k3d cluster list | grep -o "${K3D_CLUSTER_NAME}")" ]; then
    echo "K3d cluster ${K3D_CLUSTER_NAME} already exists - you may want to cleanup with: make k3d/delete"
    exit 1
  fi

  if [ "${K3D_INSTALL_DOCKER_REGISTRY}" = 'true' ] && [ ! "$(k3d registry list | grep -o "${K3D_DOCKER_REGISTRY_NAME}")" ]; then
    k3d registry create "${K3D_DOCKER_REGISTRY_NAME}" --port "${K3D_DOCKER_REGISTRY_PORT}"
  fi

  local cluster_create_args=(
    --image="${K3D_K8S_IMAGE}"
    --api-port="${K3D_API_SERVER_ADDRESS}:${K3D_API_SERVER_PORT}"
    --timeout="${K3D_WAIT}"
    --registry-create=false
  )

  if [ "${K3D_INSTALL_DOCKER_REGISTRY}" = 'true' ]; then
    cluster_create_args+=("--registry-use" "${K3D_DOCKER_REGISTRY_NAME}:${K3D_DOCKER_REGISTRY_PORT}")
	fi

  if [ "${K3D_INSTALL_LB}" = 'false' ]; then
    cluster_create_args+=("--no-lb")
    cluster_create_args+=("--k3s-server-arg" "--disable=servicelb")
    cluster_create_args+=("--k3s-server-arg" "--disable=traefik")
	fi
  set -x
  k3d cluster create "${K3D_CLUSTER_NAME}" "${cluster_create_args[@]}"
}

## Delete the cluster
delete() {
  k3d cluster delete "${K3D_CLUSTER_NAME}"
}

## Display usage
usage()
{
    echo "usage: $0 [create|delete]"
}

## Argument parsing
if [ "$#" = "0" ]; then
  usage
  exit 1
fi
    
while [ "$1" != "" ]; do
    case $1 in
        create )                create
                                ;;
        delete )                delete
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done
