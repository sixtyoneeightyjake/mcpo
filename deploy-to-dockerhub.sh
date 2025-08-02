#!/bin/bash

# MCPO Docker Deployment Script
# This script builds and pushes your MCPO image to DockerHub

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

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Get DockerHub username
if [ -z "$1" ]; then
    echo -n "Enter your DockerHub username: "
    read DOCKERHUB_USERNAME
else
    DOCKERHUB_USERNAME="$1"
fi

if [ -z "$DOCKERHUB_USERNAME" ]; then
    print_error "DockerHub username is required"
    exit 1
fi

# Get version tag (optional)
if [ -z "$2" ]; then
    echo -n "Enter version tag (optional, press Enter for 'latest'): "
    read VERSION_TAG
    if [ -z "$VERSION_TAG" ]; then
        VERSION_TAG="latest"
    fi
else
    VERSION_TAG="$2"
fi

IMAGE_NAME="$DOCKERHUB_USERNAME/mcpo"
FULL_TAG="$IMAGE_NAME:$VERSION_TAG"

print_status "Building Docker image: $FULL_TAG"

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
    print_success "Created config.json template."
fi

# Check if TAVILY_API_KEY environment variable is set
if [ -z "$TAVILY_API_KEY" ]; then
    print_warning "TAVILY_API_KEY environment variable is not set."
    echo "The Tavily API key will need to be provided when running the container."
    echo "You can set it with: export TAVILY_API_KEY='your-actual-api-key'"
    echo -n "Continue anyway? (y/N): "
    read CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        print_error "Please set the TAVILY_API_KEY environment variable and try again."
        exit 1
    fi
fi

# Build the Docker image
print_status "Building Docker image..."
if docker build -t "$FULL_TAG" .; then
    print_success "Docker image built successfully: $FULL_TAG"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Also tag as latest if not already latest
if [ "$VERSION_TAG" != "latest" ]; then
    print_status "Tagging as latest..."
    docker tag "$FULL_TAG" "$IMAGE_NAME:latest"
fi

# Check if user is logged in to DockerHub
print_status "Checking DockerHub authentication..."
if ! docker info | grep -q "Username: $DOCKERHUB_USERNAME"; then
    print_status "Logging in to DockerHub..."
    if ! docker login; then
        print_error "Failed to login to DockerHub"
        exit 1
    fi
fi

# Push the image
print_status "Pushing image to DockerHub: $FULL_TAG"
if docker push "$FULL_TAG"; then
    print_success "Successfully pushed: $FULL_TAG"
else
    print_error "Failed to push image to DockerHub"
    exit 1
fi

# Push latest tag if different from version tag
if [ "$VERSION_TAG" != "latest" ]; then
    print_status "Pushing latest tag..."
    if docker push "$IMAGE_NAME:latest"; then
        print_success "Successfully pushed: $IMAGE_NAME:latest"
    else
        print_warning "Failed to push latest tag (non-critical)"
    fi
fi

print_success "Deployment complete!"
print_status "Your image is now available at: https://hub.docker.com/r/$DOCKERHUB_USERNAME/mcpo"
print_status "To run on a remote server:"
echo "  docker run -d --name mcpo-server -p 8000:8000 --restart unless-stopped $FULL_TAG --config /app/config.json --port 8000"
print_status "Or use the docker-compose.yml example in DEPLOYMENT.md"

# Show image size
IMAGE_SIZE=$(docker images "$FULL_TAG" --format "table {{.Size}}" | tail -n 1)
print_status "Final image size: $IMAGE_SIZE"

print_success "All done! 🚀"