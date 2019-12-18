#!/bin/bash
set -x
if [[ -z "${ARM_SUBSCRIPTION}" ]]; then
  echo "Setup default value for ARM_SUBSCRIPTION !!!!"
  exit 1
fi
location="${ARM_ENVIRMENT:-westeurope}"
resourceGroup="${ARM_RESOURCE_GROUP:-weAKSMySQLResourceGroup}"
acrName="${ARM_ACR_NAME:-weaksmysqlacr}"
aksName="${ARM_AKS_NAME:-weAKSMySQLCluster}"
mysqlname="${ARM_MYSQL_NAME:-weaksmysqldemoserver}"
subscription="${ARM_SUBSCRIPTION}"

az group create --name $resourceGroup --location $location --subscription $subscription --output none

# Create the container registry
az acr create --resource-group $resourceGroup --name $acrName --sku Basic --subscription $subscription --output none

# Create the AKS cluster
az aks create \
    --resource-group $resourceGroup \
    --name $aksName \
    --vm-set-type VirtualMachineScaleSets \
    --nodepool-name noaccpool \
    --node-count 1 \
    --node-vm-size Standard_D2s_v3 \
    --generate-ssh-keys \
    --attach-acr $acrName \
    --load-balancer-sku standard \
    --subscription $subscription \
    --output none

az aks nodepool add \
    --resource-group $resourceGroup \
    --cluster-name $aksName \
    --name accpool \
    --node-count 1 \
    --node-vm-size Standard_DS2_v2 \
    --subscription $subscription \
    --output none
    
    
RG_AKS=$(az aks show --resource-group $resourceGroup --name $aksName --query "nodeResourceGroup" -o tsv --subscription $subscription)

az mysql server create --resource-group $resourceGroup --name $mysqlname  --location $location --admin-user myadmin --admin-password 5ZPdYXP4AKXQY4QX --sku-name GP_Gen5_2 --subscription $subscription --output none

AKS_VN=$(az network vnet list -g $RG_AKS --query "[0].name" -o tsv --subscription $subscription)

az network vnet subnet update -n aks-subnet --vnet-name $AKS_VN -g $RG_AKS --service-endpoints Microsoft.SQL --subscription $subscription --output none

az mysql server vnet-rule create \
    -g $resourceGroup \
    -s $mysqlname  \
    -n vnetRuleName \
    --subnet /subscriptions/$subscription/resourceGroups/$RG_AKS/providers/Microsoft.Network/virtualNetworks/$AKS_VN/subnets/aks-subnet \
    --subscription $subscription \
    --output none

myPublicIp=$(curl https://ifconfig.co/ -s)

az mysql server firewall-rule create \
    -g $resourceGroup  \
    -s $mysqlname  \
    --name "AllowAllWindowsAzureIps" \
    --start-ip-address $myPublicIp \
    --end-ip-address $myPublicIp \
    --subscription $subscription \
    --output none

mysql -h $mysqlname.mysql.database.azure.com -umyadmin@$mysqlname -p5ZPdYXP4AKXQY4QX --ssl-ca=ca.pem -e"CREATE DATABASE typo3 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

if [ -f "dump_empty.sql.gz" ]; then
    gunzip < dump_empty.sql.gz | mysql -h $mysqlname.mysql.database.azure.com -umyadmin@$mysqlname -p5ZPdYXP4AKXQY4QX --ssl-ca=ca.pem  typo3
fi



az aks get-credentials -n $aksName  -g $resourceGroup --subscription $subscription --overwrite-existing --output none

kubectl create secret generic mysql --from-literal=connection="Server=$mysqlname.mysql.database.azure.com;Port=3306;User Id=myadmin@$mysqlname;Password=5ZPdYXP4AKXQY4QX;Database=typo3"

#Restore backup from test environment
az acr login -n ${acrName,,} --subscription $subscription

docker build -t ${acrName,,}.azurecr.io/testapp .

docker push ${acrName,,}.azurecr.io/testapp

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: testapp-acc
spec:
  template:
    metadata:
      creationTimestamp: null
    spec:
      containers:
      - image: ${acrName,,}.azurecr.io/testapp
        imagePullPolicy: Always
        name: testapp
        env:
        - name: MYSQL_CONNECTION
          valueFrom:
            secretKeyRef:
              name: mysql
              key: connection
      restartPolicy: Never
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                - key: agentpool
                  operator: In
                  values:
                  - accpool
---
apiVersion: batch/v1
kind: Job
metadata:
  name: testapp-noacc
spec:
  template:
    metadata:
      creationTimestamp: null
    spec:
      containers:
      - image: ${acrName,,}.azurecr.io/testapp
        imagePullPolicy: Always
        name: testapp
        env:
        - name: MYSQL_CONNECTION
          valueFrom:
            secretKeyRef:
              name: mysql
              key: connection
      restartPolicy: Never
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                - key: agentpool
                  operator: In
                  values:
                  - noaccpool
---                  
EOF










