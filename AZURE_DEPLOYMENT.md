# Azure Container Deployment Guide for MCPO

This guide explains how to deploy your MCPO project with Context7, Tavily, and Sequential Thinking MCP servers to Azure Container Registry (ACR) and Azure Container Instances (ACI).

## Prerequisites

1. **Azure CLI installed** (`az --version` to verify)
2. **Docker installed** and running
3. **Azure subscription** with appropriate permissions
4. **Tavily API Key** (get one at https://tavily.com)

## Step 1: Azure Setup

### 1.1 Login to Azure

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "your-subscription-id"

# Verify current subscription
az account show
```

### 1.2 Create Resource Group

```bash
# Create a resource group
az group create --name mcpo-rg --location eastus
```

### 1.3 Create Azure Container Registry (ACR)

```bash
# Create ACR (name must be globally unique)
az acr create --resource-group mcpo-rg --name mcpoacr --sku Basic

# Enable admin user (for simple authentication)
az acr update -n mcpoacr --admin-enabled true

# Get login server
az acr show --name mcpoacr --query loginServer --output tsv
```

## Step 2: Build and Push to Azure Container Registry

### 2.1 Login to ACR

```bash
# Login to your ACR
az acr login --name mcpoacr
```

### 2.2 Build and Push Image

**Option A: Build locally and push**
```bash
# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name mcpoacr --query loginServer --output tsv)

# Build image with ACR tag
docker build -t $ACR_LOGIN_SERVER/mcpo:latest .

# Push to ACR
docker push $ACR_LOGIN_SERVER/mcpo:latest
```

**Option B: Build directly in ACR (recommended)**
```bash
# Build and push in one command
az acr build --registry mcpoacr --image mcpo:latest .
```

### 2.3 Verify Image in ACR

```bash
# List repositories
az acr repository list --name mcpoacr --output table

# List tags for mcpo repository
az acr repository show-tags --name mcpoacr --repository mcpo --output table
```

## Step 3: Deploy to Azure Container Instances (ACI)

### 3.1 Get ACR Credentials

```bash
# Get ACR credentials
ACR_LOGIN_SERVER=$(az acr show --name mcpoacr --query loginServer --output tsv)
ACR_USERNAME=$(az acr credential show --name mcpoacr --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name mcpoacr --query passwords[0].value --output tsv)
```

### 3.2 Deploy Container Instance

```bash
# Deploy to ACI
az container create \
  --resource-group mcpo-rg \
  --name mcpo-container \
  --image $ACR_LOGIN_SERVER/mcpo:latest \
  --registry-login-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --dns-name-label mcpo-app \
  --ports 8000 \
  --environment-variables TAVILY_API_KEY="your-actual-tavily-api-key-here" \
  --command-line "mcpo --config /app/config.json --port 8000" \
  --cpu 1 \
  --memory 2
```

### 3.3 Get Container Information

```bash
# Get container details
az container show --resource-group mcpo-rg --name mcpo-container --query "{FQDN:ipAddress.fqdn,ProvisioningState:provisioningState}" --out table

# Get logs
az container logs --resource-group mcpo-rg --name mcpo-container
```

## Step 4: Advanced Deployment with YAML

### 4.1 Create Deployment YAML

Create `azure-container-deployment.yaml`:

```yaml
apiVersion: '2021-07-01'
location: eastus
name: mcpo-container
properties:
  containers:
  - name: mcpo
    properties:
      image: mcpoacr.azurecr.io/mcpo:latest
      ports:
      - port: 8000
        protocol: TCP
      environmentVariables:
      - name: TAVILY_API_KEY
        secureValue: your-actual-tavily-api-key-here
      command:
      - mcpo
      - --config
      - /app/config.json
      - --port
      - "8000"
      resources:
        requests:
          cpu: 1.0
          memoryInGb: 2.0
  imageRegistryCredentials:
  - server: mcpoacr.azurecr.io
    username: mcpoacr
    password: your-acr-password-here
  ipAddress:
    type: Public
    ports:
    - protocol: TCP
      port: 8000
    dnsNameLabel: mcpo-app
  osType: Linux
  restartPolicy: Always
tags:
  environment: production
  application: mcpo
type: Microsoft.ContainerInstance/containerGroups
```

### 4.2 Deploy with YAML

```bash
# Deploy using YAML
az container create --resource-group mcpo-rg --file azure-container-deployment.yaml
```

## Step 5: Production Considerations

### 5.1 Use Azure Key Vault for Secrets

```bash
# Create Key Vault
az keyvault create --name mcpo-keyvault --resource-group mcpo-rg --location eastus

# Store Tavily API key
az keyvault secret set --vault-name mcpo-keyvault --name tavily-api-key --value "your-actual-api-key"

# Grant ACI access to Key Vault (requires managed identity)
az role assignment create --assignee <managed-identity-principal-id> --role "Key Vault Secrets User" --scope /subscriptions/<subscription-id>/resourceGroups/mcpo-rg/providers/Microsoft.KeyVault/vaults/mcpo-keyvault
```

### 5.2 Enable Managed Identity

```yaml
# Add to your YAML deployment
identity:
  type: SystemAssigned
```

### 5.3 Use Azure Container Apps (Alternative)

For more advanced scenarios, consider Azure Container Apps:

```bash
# Create Container Apps environment
az containerapp env create \
  --name mcpo-env \
  --resource-group mcpo-rg \
  --location eastus

# Deploy to Container Apps
az containerapp create \
  --name mcpo-app \
  --resource-group mcpo-rg \
  --environment mcpo-env \
  --image mcpoacr.azurecr.io/mcpo:latest \
  --registry-server mcpoacr.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --target-port 8000 \
  --ingress external \
  --env-vars TAVILY_API_KEY="your-actual-api-key" \
  --cpu 1.0 \
  --memory 2.0Gi
```

## Step 6: Monitoring and Scaling

### 6.1 Enable Application Insights

```bash
# Create Application Insights
az monitor app-insights component create \
  --app mcpo-insights \
  --location eastus \
  --resource-group mcpo-rg

# Get instrumentation key
az monitor app-insights component show \
  --app mcpo-insights \
  --resource-group mcpo-rg \
  --query instrumentationKey
```

### 6.2 Set up Log Analytics

```bash
# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group mcpo-rg \
  --workspace-name mcpo-logs

# Get workspace ID and key
az monitor log-analytics workspace show \
  --resource-group mcpo-rg \
  --workspace-name mcpo-logs \
  --query customerId
```

## Step 7: Automated Deployment Script

Create `deploy-to-azure.sh`:

```bash
#!/bin/bash

set -e

# Configuration
RESOURCE_GROUP="mcpo-rg"
ACR_NAME="mcpoacr"
CONTAINER_NAME="mcpo-container"
LOCATION="eastus"
DNS_LABEL="mcpo-app"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting Azure deployment...${NC}"

# Check if logged in
if ! az account show &> /dev/null; then
    echo "Please login to Azure first: az login"
    exit 1
fi

# Create resource group if it doesn't exist
echo -e "${BLUE}Creating resource group...${NC}"
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR if it doesn't exist
echo -e "${BLUE}Creating Azure Container Registry...${NC}"
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

# Build and push image
echo -e "${BLUE}Building and pushing image...${NC}"
az acr build --registry $ACR_NAME --image mcpo:latest .

# Get ACR details
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value --output tsv)

# Deploy to ACI
echo -e "${BLUE}Deploying to Azure Container Instances...${NC}"
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --image $ACR_LOGIN_SERVER/mcpo:latest \
  --registry-login-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --dns-name-label $DNS_LABEL \
  --ports 8000 \
  --environment-variables TAVILY_API_KEY="$TAVILY_API_KEY" \
  --command-line "mcpo --config /app/config.json --port 8000" \
  --cpu 1 \
  --memory 2

# Get deployment info
FQDN=$(az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query ipAddress.fqdn --output tsv)

echo -e "${GREEN}Deployment complete!${NC}"
echo -e "${GREEN}Your MCPO server is available at: http://$FQDN:8000${NC}"
echo -e "${GREEN}API Documentation: http://$FQDN:8000/docs${NC}"
echo -e "${GREEN}Context7: http://$FQDN:8000/context7/docs${NC}"
echo -e "${GREEN}Tavily: http://$FQDN:8000/tavily/docs${NC}"
echo -e "${GREEN}Sequential Thinking: http://$FQDN:8000/sequential-thinking/docs${NC}"
```

## Step 8: Cleanup

### 8.1 Delete Resources

```bash
# Delete container instance
az container delete --resource-group mcpo-rg --name mcpo-container --yes

# Delete entire resource group (removes all resources)
az group delete --name mcpo-rg --yes --no-wait
```

## Troubleshooting

### Common Issues

1. **ACR Authentication Issues**
   ```bash
   # Re-login to ACR
   az acr login --name mcpoacr
   ```

2. **Container Won't Start**
   ```bash
   # Check logs
   az container logs --resource-group mcpo-rg --name mcpo-container
   
   # Check container events
   az container show --resource-group mcpo-rg --name mcpo-container --query instanceView.events
   ```

3. **DNS Issues**
   ```bash
   # Check if DNS label is available
   az container show --resource-group mcpo-rg --name mcpo-container --query ipAddress
   ```

4. **Resource Limits**
   ```bash
   # Check resource usage
   az container show --resource-group mcpo-rg --name mcpo-container --query containers[0].instanceView.currentState
   ```

### Useful Commands

```bash
# Restart container
az container restart --resource-group mcpo-rg --name mcpo-container

# Update container (requires recreation)
az container delete --resource-group mcpo-rg --name mcpo-container --yes
# Then recreate with new settings

# Monitor container
az container attach --resource-group mcpo-rg --name mcpo-container

# Export container logs
az container logs --resource-group mcpo-rg --name mcpo-container > container.log
```

## Cost Optimization

1. **Use appropriate sizing**: Start with 1 CPU and 2GB RAM, adjust based on usage
2. **Consider Azure Container Apps**: Better for production workloads with auto-scaling
3. **Use Azure Spot Instances**: For development/testing environments
4. **Set up auto-shutdown**: For non-production environments

---

**Your MCPO server with Context7, Tavily, and Sequential Thinking MCP servers is now running on Azure! 🚀**