#!/bin/bash

# MCPO Azure Deployment Script
# This script deploys your MCPO image to Azure Container Registry and Azure Container Instances

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    print_error "Please login to Azure first: az login"
    exit 1
fi

# Configuration with defaults
RESOURCE_GROUP="${1:-mcpo-rg}"
ACR_NAME="${2:-mcpoacr}"
CONTAINER_NAME="${3:-mcpo-container}"
LOCATION="${4:-eastus}"
DNS_LABEL="${5:-mcpo-app}"

# Get Tavily API key
if [ -z "$TAVILY_API_KEY" ]; then
    echo -n "Enter your Tavily API key: "
    read -s TAVILY_API_KEY
    echo
fi

if [ -z "$TAVILY_API_KEY" ]; then
    print_error "Tavily API key is required"
    exit 1
fi

print_status "Starting Azure deployment with configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  ACR Name: $ACR_NAME"
echo "  Container Name: $CONTAINER_NAME"
echo "  Location: $LOCATION"
echo "  DNS Label: $DNS_LABEL"
echo

# Check if config.json exists
if [ ! -f "config.json" ]; then
    print_warning "config.json not found. Creating a template..."
    cat > config.json << 'EOF'
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "tavily": {
      "command": "npx",
      "args": ["-y", "tavily-mcp@0.1.3"]
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
EOF
    print_success "Created config.json template"
fi

# Create resource group
print_status "Creating resource group: $RESOURCE_GROUP"
if az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none; then
    print_success "Resource group created or already exists"
else
    print_error "Failed to create resource group"
    exit 1
fi

# Use Docker Hub image instead of ACR
DOCKER_IMAGE="sixtyoneeightyjake/mcpo:latest"
print_status "Using Docker Hub image: $DOCKER_IMAGE"

# Check if container already exists and delete it
if az container show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME" &> /dev/null; then
    print_warning "Container $CONTAINER_NAME already exists. Deleting..."
    az container delete --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME" --yes --output none
    print_success "Existing container deleted"
fi

# Deploy to ACI
print_status "Deploying to Azure Container Instances..."
if az container create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_NAME" \
  --image "$DOCKER_IMAGE" \
  --dns-name-label "$DNS_LABEL" \
  --ports 8000 \
  --os-type Linux \
  --environment-variables TAVILY_API_KEY="$TAVILY_API_KEY" \
  --command-line "mcpo --config /app/config.json --port 8000" \
  --cpu 1 \
  --memory 2 \
  --output none; then
    print_success "Container deployed successfully"
else
    print_error "Failed to deploy container"
    exit 1
fi

# Wait for container to be ready
print_status "Waiting for container to be ready..."
sleep 30

# Get deployment info
print_status "Retrieving deployment information..."
FQDN=$(az container show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME" --query ipAddress.fqdn --output tsv)
STATE=$(az container show --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME" --query instanceView.state --output tsv)

if [ -z "$FQDN" ]; then
    print_error "Failed to retrieve container FQDN"
    exit 1
fi

print_success "Deployment complete!"
echo
print_status "Container State: $STATE"
print_status "Your MCPO server is available at: http://$FQDN:8000"
print_status "API Documentation: http://$FQDN:8000/docs"
print_status "Context7 MCP Server: http://$FQDN:8000/context7/docs"
print_status "Tavily MCP Server: http://$FQDN:8000/tavily/docs"
print_status "Sequential Thinking MCP Server: http://$FQDN:8000/sequential-thinking/docs"
echo

# Show container logs
print_status "Recent container logs:"
az container logs --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME" --tail 20

echo
print_success "Azure deployment completed successfully! 🚀"
print_status "To view logs: az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"
print_status "To delete: az container delete --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --yes"
print_status "To delete all resources: az group delete --name $RESOURCE_GROUP --yes --no-wait"

# Test the deployment
print_status "Testing deployment..."
if curl -f "http://$FQDN:8000/docs" &> /dev/null; then
    print_success "Deployment test passed! Server is responding."
else
    print_warning "Deployment test failed. Server may still be starting up."
    print_status "You can check the status with: az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME"
fi