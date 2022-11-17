#!/bin/sh

# <--- Change the following environment variables according to your Azure service principal name --->

echo "Exporting environment variables"
export appId='660b73c0-f6a0-4c67-bf43-e6300d55c018'
export password='7sA8Q~QA8t6Ser2fVw6aqI3nK1B-ZPyQ4~J~lap7'
export tenantId='16b3c013-d300-468d-ac64-7eda0820b6d3'
export resourceGroup='arc'
export arcClusterName='arc'
export appClonedRepo='https://github.com/cplemm/azure-arc-jumpstart-apps'
export namespace='hello-arc'

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI
echo "Installing Azure CLI"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Installing required Azure Arc CLI extensions
az extension add --name connectedk8s
az extension add --name k8s-configuration

# Login to Azure
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password $password --tenant $tenantId

# Registering Azure Arc providers
echo "Registering Azure Arc providers"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

az provider show -n Microsoft.Kubernetes -o table
az provider show -n Microsoft.KubernetesConfiguration -o table
az provider show -n Microsoft.ExtendedLocation -o table

# Create a namespace for your ingress and app resources
kubectl create ns $namespace

# Add the official stable repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Use Helm to deploy an NGINX ingress controller
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace $namespace

# Create GitOps config for Hello-Arc app
echo "Creating GitOps config for Hello-Arc app"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc \
--namespace $namespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=app path=./hello-arc/yaml

# Create GitOps config for Hello-Arc Ingress
echo "Creating GitOps config for Hello-Arc Ingress"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc-ingress \
--namespace $namespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch main \
--kustomization name=ingress path=./hello-arc/ingress