#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 GCP Lab - Build and Push Docker Images${NC}\n"

# Check if PROJECT_ID is set
if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}⚠️  PROJECT_ID not set. Please run:${NC}"
    echo "export PROJECT_ID=your-gcp-project-id"
    exit 1
fi

# Configuration
REGION=${REGION:-us-central1}
BACKEND_IMAGE="gcr.io/${PROJECT_ID}/lab-backend:latest"
FRONTEND_IMAGE="gcr.io/${PROJECT_ID}/lab-frontend:latest"

echo -e "${GREEN}📦 Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Backend Image: $BACKEND_IMAGE"
echo "  Frontend Image: $FRONTEND_IMAGE"
echo ""

# Build backend
echo -e "${BLUE}🔨 Building backend...${NC}"
cd apps/backend
docker build -t $BACKEND_IMAGE .
echo -e "${GREEN}✅ Backend built${NC}\n"

# Build frontend with backend URL
echo -e "${BLUE}🔨 Building frontend...${NC}"
cd ../frontend
# Get backend URL from terraform output if available
BACKEND_URL=$(cd ../../ && terraform output -raw backend_url 2>/dev/null || echo "")
if [ -z "$BACKEND_URL" ]; then
    echo -e "${YELLOW}⚠️  Could not get backend URL from terraform, using placeholder${NC}"
    BACKEND_URL="https://BACKEND_URL_HERE"
fi

docker build \
    --build-arg REACT_APP_BACKEND_URL=$BACKEND_URL \
    --build-arg REACT_APP_ENVIRONMENT=production \
    -t $FRONTEND_IMAGE .
echo -e "${GREEN}✅ Frontend built${NC}\n"

# Push images
echo -e "${BLUE}📤 Pushing images to GCR...${NC}"
docker push $BACKEND_IMAGE
echo -e "${GREEN}✅ Backend pushed${NC}"

docker push $FRONTEND_IMAGE
echo -e "${GREEN}✅ Frontend pushed${NC}\n"

# Update terraform.tfvars
echo -e "${BLUE}📝 Updating terraform.tfvars...${NC}"
cd ../../
if [ -f terraform.tfvars ]; then
    # Update or add image variables
    if grep -q "frontend_image" terraform.tfvars; then
        sed -i.bak "s|frontend_image.*|frontend_image = \"$FRONTEND_IMAGE\"|" terraform.tfvars
        sed -i.bak "s|backend_image.*|backend_image = \"$BACKEND_IMAGE\"|" terraform.tfvars
        rm terraform.tfvars.bak
    else
        echo "" >> terraform.tfvars
        echo "# Container images" >> terraform.tfvars
        echo "frontend_image = \"$FRONTEND_IMAGE\"" >> terraform.tfvars
        echo "backend_image  = \"$BACKEND_IMAGE\"" >> terraform.tfvars
    fi
    echo -e "${GREEN}✅ terraform.tfvars updated${NC}\n"
fi

echo -e "${GREEN}🎉 Done! Images are ready.${NC}\n"
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Run: terraform apply"
echo "  2. Wait for deployment (~5 minutes)"
echo "  3. Visit your frontend URL"
echo ""
