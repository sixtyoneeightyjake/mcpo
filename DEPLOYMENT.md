# Docker Deployment Guide for MCPO with MCP Servers

This guide explains how to build, push, and deploy your MCPO project with Context7, Tavily, and Sequential Thinking MCP servers to DockerHub and remote servers.

## Prerequisites

1. **Docker installed** on your local machine
2. **DockerHub account** (free at https://hub.docker.com)
3. **Tavily API Key** (get one at https://tavily.com)

## Step 1: Prepare Your Environment

### 1.1 Set your Tavily API Key as Environment Variable

Set your Tavily API key as an environment variable instead of hardcoding it in config.json:

```bash
# Set the environment variable
export TAVILY_API_KEY="your-actual-tavily-api-key-here"

# Verify it's set
echo $TAVILY_API_KEY
```

Your `config.json` should look like this (no API key needed):

```json
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
```

**Note:** The MCPO application will automatically use the `TAVILY_API_KEY` environment variable for the Tavily server.

### 1.2 Login to DockerHub

```bash
docker login
```

Enter your DockerHub username and password when prompted.

## Step 2: Build the Docker Image

### 2.1 Build the image locally

```bash
# Replace 'yourusername' with your actual DockerHub username
docker build -t yourusername/mcpo:latest .
```

### 2.2 Tag with version (optional but recommended)

```bash
# Tag with a specific version
docker tag yourusername/mcpo:latest yourusername/mcpo:v1.0.0
```

## Step 3: Push to DockerHub

### 3.1 Push the latest tag

```bash
docker push yourusername/mcpo:latest
```

### 3.2 Push the version tag (if created)

```bash
docker push yourusername/mcpo:v1.0.0
```

## Step 4: Deploy on Remote Server

### 4.1 SSH into your remote server

```bash
ssh user@your-server-ip
```

### 4.2 Install Docker (if not already installed)

**For Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install docker.io docker-compose -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

**For CentOS/RHEL:**
```bash
sudo yum install docker docker-compose -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 4.3 Pull and run your Docker image

```bash
# Pull the image from DockerHub
docker pull yourusername/mcpo:latest

# Run the container
docker run -d \
  --name mcpo-server \
  -p 8000:8000 \
  --restart unless-stopped \
  yourusername/mcpo:latest \
  --config /app/config.json --port 8000
```

### 4.4 Alternative: Using Docker Compose (Recommended)

Create a `docker-compose.yml` file on your remote server:

```yaml
version: '3.8'

services:
  mcpo:
    image: yourusername/mcpo:latest
    container_name: mcpo-server
    ports:
      - "8000:8000"
    command: ["--config", "/app/config.json", "--port", "8000"]
    restart: unless-stopped
    environment:
      - TAVILY_API_KEY=your-actual-tavily-api-key-here
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/docs"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

Then run:

```bash
docker-compose up -d
```

## Step 5: Verify Deployment

### 5.1 Check if the container is running

```bash
docker ps
```

### 5.2 Check logs

```bash
docker logs mcpo-server
```

### 5.3 Test the endpoints

```bash
# Test the main API documentation
curl http://your-server-ip:8000/docs

# Test individual MCP server endpoints
curl http://your-server-ip:8000/context7/docs
curl http://your-server-ip:8000/tavily/docs
curl http://your-server-ip:8000/sequential-thinking/docs
```

## Step 6: Production Considerations

### 6.1 Environment Variables

For production, avoid hardcoding API keys in config files. Use environment variables:

```bash
# Set environment variable on the server
export TAVILY_API_KEY="your-actual-api-key"

# Run container with environment variable
docker run -d \
  --name mcpo-server \
  -p 8000:8000 \
  -e TAVILY_API_KEY="$TAVILY_API_KEY" \
  --restart unless-stopped \
  yourusername/mcpo:latest \
  --config /app/config.json --port 8000
```

### 6.2 Reverse Proxy (Nginx)

For production deployments, consider using a reverse proxy:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 6.3 SSL/TLS with Let's Encrypt

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx -y

# Get SSL certificate
sudo certbot --nginx -d your-domain.com
```

### 6.4 Monitoring and Logging

```bash
# View real-time logs
docker logs -f mcpo-server

# Set up log rotation
docker run -d \
  --name mcpo-server \
  -p 8000:8000 \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  --restart unless-stopped \
  yourusername/mcpo:latest \
  --config /app/config.json --port 8000
```

## Troubleshooting

### Common Issues

1. **Container won't start**: Check logs with `docker logs mcpo-server`
2. **Port already in use**: Change the host port mapping `-p 8001:8000`
3. **MCP servers not connecting**: Verify Node.js and npm are available in the container
4. **Tavily API errors**: Ensure your API key is valid and has sufficient quota

### Useful Commands

```bash
# Stop the container
docker stop mcpo-server

# Remove the container
docker rm mcpo-server

# Update to latest image
docker pull yourusername/mcpo:latest
docker stop mcpo-server
docker rm mcpo-server
# Then run the container again

# Execute commands inside the container
docker exec -it mcpo-server /bin/bash
```

## Automated Deployment with GitHub Actions

The project already includes GitHub Actions workflows for automated Docker builds. To use them:

1. Fork the repository
2. Update the image name in `.github/workflows/docker-build.yaml`
3. Push to the `main` branch to trigger automatic builds
4. Images will be pushed to GitHub Container Registry (ghcr.io)

## Security Best Practices

1. **Never commit API keys** to version control
2. **Use environment variables** for sensitive data
3. **Regularly update** base images and dependencies
4. **Use non-root users** in containers when possible
5. **Implement proper firewall rules** on your server
6. **Enable Docker security scanning** for vulnerabilities

---

**Your MCPO server with Context7, Tavily, and Sequential Thinking MCP servers is now ready for production deployment!**