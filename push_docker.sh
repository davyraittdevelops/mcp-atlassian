#!/bin/bash
set -e

# Configuration
DOCKER_USERNAME="davyraitt"
IMAGE_NAME="mcp_atlassian"
TARGET_PLATFORM="linux/amd64"  # Force AMD64 for AWS/Linux servers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🐳 MCP Atlassian Docker Build Script${NC}"
echo "=================================="

# Check Docker buildx
if ! docker buildx version > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Setting up Docker buildx...${NC}"
    docker buildx create --name multiplatform --use
    docker buildx inspect --bootstrap
fi

# Get current branch and commit info
CURRENT_BRANCH=$(git branch --show-current)
GIT_HASH=$(git rev-parse --short HEAD)

# Create version tag based on branch
if [ "$CURRENT_BRANCH" = "main" ]; then
    VERSION="v1.0.${GIT_HASH}"
    TAG_SUFFIX=""
else
    VERSION="v1.0.${CURRENT_BRANCH}-${GIT_HASH}"
    TAG_SUFFIX="-${CURRENT_BRANCH}"
fi

FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}"

echo -e "${BLUE}📋 Build Information:${NC}"
echo "   Branch: ${CURRENT_BRANCH}"
echo "   Commit: ${GIT_HASH}"
echo "   Version: ${VERSION}"
echo "   Image: ${FULL_IMAGE_NAME}:latest${TAG_SUFFIX}"
echo "   Platform: ${TARGET_PLATFORM}"
echo ""

# Confirm build
read -p "Continue with build? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Build cancelled.${NC}"
    exit 0
fi

echo -e "${BLUE}🔨 Building Docker image...${NC}"

# Build and push
if [ "$CURRENT_BRANCH" = "main" ]; then
    # Main branch gets 'latest' tag
    docker buildx build \
        --platform ${TARGET_PLATFORM} \
        --tag "${FULL_IMAGE_NAME}:latest" \
        --tag "${FULL_IMAGE_NAME}:${VERSION}" \
        --push \
        .
else
    # Feature branches get branch-specific tags
    docker buildx build \
        --platform ${TARGET_PLATFORM} \
        --tag "${FULL_IMAGE_NAME}:latest-${CURRENT_BRANCH}" \
        --tag "${FULL_IMAGE_NAME}:${VERSION}" \
        --push \
        .
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build and push successful!${NC}"
    echo ""
    echo -e "${GREEN}📦 Published Images:${NC}"
    if [ "$CURRENT_BRANCH" = "main" ]; then
        echo "   ${FULL_IMAGE_NAME}:latest"
    else
        echo "   ${FULL_IMAGE_NAME}:latest-${CURRENT_BRANCH}"
    fi
    echo "   ${FULL_IMAGE_NAME}:${VERSION}"
    echo ""
    echo -e "${BLUE}🔄 To use in docker-compose.yml:${NC}"
    if [ "$CURRENT_BRANCH" = "main" ]; then
        echo "   image: ${FULL_IMAGE_NAME}:latest"
    else
        echo "   image: ${FULL_IMAGE_NAME}:latest-${CURRENT_BRANCH}"
    fi
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi
