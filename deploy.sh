#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Sora2API Deploy Script ===${NC}"

# 1. Configuration
# ----------------
echo -e "${YELLOW}Step 1: Configuration${NC}"

# Check/Get Project ID
if [ -z "$PROJECT_ID" ]; then
    read -p "Enter your Google Cloud Project ID: " PROJECT_ID
    if [ -z "$PROJECT_ID" ]; then
        echo "Error: Project ID is required."
        exit 1
    fi
fi

# Check/Get Region
if [ -z "$REGION" ]; then
    read -p "Enter Region (default: asia-northeast1): " input_region
    REGION=${input_region:-asia-northeast1}
fi

export PROJECT_ID
export REGION

# Set other variables
SERVICE_NAME="sora2api"
REPO_NAME="sora2api-repo"
BUCKET_NAME="${PROJECT_ID}-sora2api-data"
IMAGE_TAG="$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/$SERVICE_NAME:latest"

echo "--------------------------------"
echo "Project ID:   $PROJECT_ID"
echo "Region:       $REGION"
echo "Service Name: $SERVICE_NAME"
echo "Bucket Name:  $BUCKET_NAME"
echo "Repository:   $REPO_NAME"
echo "--------------------------------"

# Confirm with user
# read -p "Press Enter to continue or Ctrl+C to cancel..."

# Set project
gcloud config set project "$PROJECT_ID"

# 2. Setup Resources
# ------------------
echo -e "\n${YELLOW}Step 2: Setting up Resources${NC}"

# Create Bucket if checks fail (simple check by trying to describe)
if ! gcloud storage buckets describe "gs://$BUCKET_NAME" &>/dev/null; then
    echo "Creating Storage Bucket: gs://$BUCKET_NAME..."
    gcloud storage buckets create "gs://$BUCKET_NAME" --location="$REGION"
else
    echo "Storage Bucket gs://$BUCKET_NAME already exists."
fi

# Create Artifact Registry if checks fail
if ! gcloud artifacts repositories describe "$REPO_NAME" --location="$REGION" &>/dev/null; then
    echo "Creating Artifact Registry Repository: $REPO_NAME..."
    gcloud artifacts repositories create "$REPO_NAME" \
        --repository-format=docker \
        --location="$REGION" \
        --description="Sora2API Docker Repository"
else
    echo "Artifact Registry Repository $REPO_NAME already exists."
fi

# 3. Build & Push
# ---------------
echo -e "\n${YELLOW}Step 3: Building and Pushing Image${NC}"
echo "Submitting build to Cloud Build..."
gcloud builds submit --tag "$IMAGE_TAG" .

# 4. Deploy
# ---------
echo -e "\n${YELLOW}Step 4: Deploying to Cloud Run${NC}"

gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE_TAG" \
  --region "$REGION" \
  --allow-unauthenticated \
  --port 8000 \
  --execution-environment gen2 \
  --add-volume=name=gcs-data,type=cloud-storage,bucket="$BUCKET_NAME" \
  --add-volume-mount=volume=gcs-data,mount-path=/mnt/gcs \
  --timeout 300 \
  --memory 2Gi \
  --cpu 1

echo -e "\n${GREEN}=== Deployment Complete! ===${NC}"
echo "You can manage your service at: https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME/metrics?project=$PROJECT_ID"
