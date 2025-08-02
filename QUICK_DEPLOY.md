# Quick Deploy Guide - MCPO Deployment Options

## 🚀 Quick Start (5 minutes)

### 1. Prerequisites
- Docker installed and running
- **For DockerHub**: DockerHub account
- **For Azure**: Azure CLI installed and Azure subscription
- Tavily API key (get free at https://tavily.com)

### 2. Set Environment Variable
Set your Tavily API key as an environment variable:

```bash
# Set the environment variable
export TAVILY_API_KEY="tvly-your-actual-key-here"

# Verify it's set
echo $TAVILY_API_KEY
```

**Note:** The config.json no longer needs to contain your API key - it will be automatically picked up from the environment variable.

### 3. Deploy to DockerHub

**Option A: Automated Script**
```bash
./deploy-to-dockerhub.sh yourusername
```

**Option B: Manual Commands**
```bash
# Build
docker build -t yourusername/mcpo:latest .

# Login
docker login

# Push
docker push yourusername/mcpo:latest
```

### 3. Alternative: Deploy to Azure

**Option A: Automated Azure Script**
```bash
# Set your Tavily API key
export TAVILY_API_KEY="your-actual-key-here"

# Deploy to Azure (uses default settings)
./deploy-to-azure.sh

# Or with custom settings
./deploy-to-azure.sh my-resource-group my-acr-name my-container eastus my-dns-label
```

**Option B: Manual Azure Commands**
```bash
# Login to Azure
az login

# Create resource group
az group create --name mcpo-rg --location eastus

# Create ACR and build image
az acr create --resource-group mcpo-rg --name mcpoacr --sku Basic --admin-enabled true
az acr build --registry mcpoacr --image mcpo:latest .

# Deploy to ACI
ACR_LOGIN_SERVER=$(az acr show --name mcpoacr --query loginServer --output tsv)
ACR_USERNAME=$(az acr credential show --name mcpoacr --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name mcpoacr --query passwords[0].value --output tsv)

az container create \
  --resource-group mcpo-rg \
  --name mcpo-container \
  --image $ACR_LOGIN_SERVER/mcpo:latest \
  --registry-login-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --dns-name-label mcpo-app \
  --ports 8000 \
  --environment-variables TAVILY_API_KEY="your-actual-key" \
  --command-line "mcpo --config /app/config.json --port 8000" \
  --cpu 1 \
  --memory 2
```

### 4. Deploy on Remote Server

**Copy docker-compose.yml to your server:**
```bash
scp docker-compose.yml user@server:/path/to/deployment/
```

**Update docker-compose.yml on server:**
- Replace `yourusername` with your DockerHub username
- Replace `your-actual-tavily-api-key-here` with your API key

**Run on server:**
```bash
docker-compose up -d
```

### 5. Verify Deployment
```bash
# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Test endpoints
curl http://your-server:8000/docs
```

## 🔧 Available Endpoints After Deployment

**For DockerHub deployment on remote server:**
- **Main API**: `http://your-server:8000/docs`
- **Context7**: `http://your-server:8000/context7/docs`
- **Tavily**: `http://your-server:8000/tavily/docs`
- **Sequential Thinking**: `http://your-server:8000/sequential-thinking/docs`

**For Azure deployment:**
- **Main API**: `http://your-dns-label.eastus.azurecontainer.io:8000/docs`
- **Context7**: `http://your-dns-label.eastus.azurecontainer.io:8000/context7/docs`
- **Tavily**: `http://your-dns-label.eastus.azurecontainer.io:8000/tavily/docs`
- **Sequential Thinking**: `http://your-dns-label.eastus.azurecontainer.io:8000/sequential-thinking/docs`

## 🛠️ Troubleshooting

**DockerHub Deployment:**
- **Container won't start?** `docker-compose logs mcpo`
- **Port already in use?** Edit docker-compose.yml: `"8001:8000"`
- **API key issues?** `docker-compose exec mcpo env | grep TAVILY`

**Azure Deployment:**
- **Container won't start?** `az container logs --resource-group mcpo-rg --name mcpo-container`
- **DNS issues?** `az container show --resource-group mcpo-rg --name mcpo-container --query ipAddress`
- **Resource limits?** `az container show --resource-group mcpo-rg --name mcpo-container --query containers[0].instanceView.currentState`
- **ACR authentication?** `az acr login --name mcpoacr`

## 📚 Full Documentation

For detailed instructions, security best practices, and advanced configurations, see:
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Complete DockerHub deployment guide
- [AZURE_DEPLOYMENT.md](./AZURE_DEPLOYMENT.md) - Complete Azure deployment guide
- [README.md](./README.md) - Project overview and usage

---

**That's it! Your MCPO server with all three MCP servers is now running in production! 🎉**

**Choose your deployment platform:**
- 🐳 **DockerHub**: Great for self-hosted servers and traditional VPS deployments
- ☁️ **Azure**: Perfect for cloud-native deployments with built-in scaling and monitoring