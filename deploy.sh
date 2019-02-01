#!/bin/bash

export SUBSCRIPTION_NAME=subname
export AKS_SERVICE_GROUP=aksminecraft-server
export AKS_SERVICE_NAME=aksminecraft-aks
export ACR_NAME=myacrname
export LOCATION=westus2
#export VNET_NAME=
#export VNET_RESOURCE_GROUP=
#export SUBNET_NAME=
#export SERVICE_PRINCIPAL_ID


#Run az login if not already logged into a valid Azure subscription

SESSION_SUB=$(az account show --query "name" -o tsv)

if [ $SESSION_SUB != $SUBSCRIPTION_NAME ]; then
    az account set -s $SUBSCRIPTION_NAME
fi

#create resource group for AKS service

az group create -n $AKS_SERVICE_GROUP -l $LOCATION

#create aks cluster resource

az aks create -n $AKS_SERVICE_NAME -g $AKS_SERVICE_GROUP \
#--network-plugin azure --vnet-subnet-id \
#$(az network vnet subnet show -n $SUBNET_NAME --vnet-name $VNET_NAME -g $VNET_RESOURCE_GROUP --query "id" -o tsv) \
#--service-principal \
#--client-secret \
#many other configuration options can be set; use 'az aks create --help' for more options

#check for unique name for our registry and
if [ $(az acr check-name -n $ACR_NAME --query "nameAvailable") = false ]; then
    RANDO=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4 ; echo '')
    ACR_NAME=${ACR_NAME}${RANDO}
fi

#create the registry
az acr create -n $ACR_NAME -g $AKS_SERVICE_GROUP \
#--sku Standard|Premium


if [ ! $SERVICE_PRINCIPAL_ID ];then
    $SERVICE_PRINCIPAL_ID=`cat ~/.azure/aksServicePrincipal.json | jq '.[].service_principal' | tr -d '"'`
fi

#Get our registry's resourceid
ACR_ID=$(az acr show --resource-group $AKS_SERVICE_GROUP --name $ACR_NAME --query "id" --output tsv) 

#Assign the aks service principal to the Reader role on the registry
az role assignment create --assignee $SERVICE_PRINCIPAL_ID --scope $ACR_ID --role Reader 

#install registry creds into docker
az acr login -n $ACR_NAME

#pull itzg/minecraft-server image from docker hub
docker pull itzg/minecraft-server:latest

#then we are going to blatently push his image to our own private repo \
#but here we could also customize this image and create a docker file to build ourselves \
#or have ACR build it.  See 'az acr build --help' for more info

docker tag itzg/minecraft-server:latest $ACR_NAME.azurecr.io/minecraft-server:latest
docker push $ACR_NAME.azurecr.io/minecraft-server:latest

#Building a storage account in the managed Resource Group gives our ServicePrincipal the correct \
#permissions to manage dynamic volume claims. 

MANAGED_GROUP=MC_${AKS_SERVICE_GROUP}_${AKS_SERVICE_NAME}_${LOCATION}

az storage account create -n ##TODO