# Quick Deploy Guide - MCPO to DockerHub

## 🚀 Quick Start (5 minutes)

### 1. Prerequisites
- Docker installed and running
- DockerHub account
- Tavily API key (get free at https://tavily.com)

### 2. Update Configuration
Edit `config.json` and replace `your-tavily-api-key-here` with your actual API key:

```json
{
  "mcpServers": {
    "tavily": {
      "env": {
        "TAVILY_API_KEY": "tvly-your-actual-key-here"
      }
    }
  }
}
```

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

- **Main API**: `http://your-server:8000/docs`
- **Context7**: `http://your-server:8000/context7/docs`
- **Tavily**: `http://your-server:8000/tavily/docs`
- **Sequential Thinking**: `http://your-server:8000/sequential-thinking/docs`

## 🛠️ Troubleshooting

**Container won't start?**
```bash
docker-compose logs mcpo
```

**Port already in use?**
Edit docker-compose.yml: `"8001:8000"`

**API key issues?**
Check environment variables:
```bash
docker-compose exec mcpo env | grep TAVILY
```

## 📚 Full Documentation

For detailed instructions, security best practices, and advanced configurations, see:
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Complete deployment guide
- [README.md](./README.md) - Project overview and usage

---

**That's it! Your MCPO server with all three MCP servers is now running in production! 🎉**