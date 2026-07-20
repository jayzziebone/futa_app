#!/bin/bash
# FUTA Backend Deployment Script for Google Cloud Run
# Target Project: futa-1c8d8

set -e # Exit immediately if a command exits with a non-zero status

# 1. Configuration variables
PROJECT_ID="futa-1c8d8"
SERVICE_NAME="futa-backend"
REGION="us-central1"
IMAGE_TAG="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest"

echo "=========================================================="
echo "🚀 Initialisation du déploiement FUTA sur Google Cloud Run"
echo "🎯 Projet Google Cloud : ${PROJECT_ID}"
echo "=========================================================="

# 2. Set the active gcloud project
echo "⚙️ Configuration du projet actif dans le CLI gcloud..."
gcloud config set project "${PROJECT_ID}"

# 3. Submit build to Google Cloud Build
echo "📦 Compilation de l'image de conteneur avec Cloud Build..."
gcloud builds submit --tag "${IMAGE_TAG}" .

# 4. Deploy container to Google Cloud Run
echo "⚡ Déploiement du conteneur sur Google Cloud Run..."
if [ -z "${SUPABASE_KEY}" ]; then
  echo "⚠️ SUPABASE_KEY n'est pas configuré dans votre environnement."
  echo "Veuillez exécuter: export SUPABASE_KEY=\"votre_clé_de_service\""
  exit 1
fi

if [ -z "${SUPABASE_JWT_SECRET}" ]; then
  echo "⚠️ SUPABASE_JWT_SECRET n'est pas configuré dans votre environnement."
  echo "Veuillez exécuter: export SUPABASE_JWT_SECRET=\"votre_secret_jwt_supabase\""
  exit 1
fi

gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE_TAG}" \
  --platform managed \
  --region "${REGION}" \
  --allow-unauthenticated \
  --set-env-vars SUPABASE_URL="https://ybqrztudctjctomvmxox.supabase.co",SUPABASE_KEY="${SUPABASE_KEY}",SUPABASE_JWT_SECRET="${SUPABASE_JWT_SECRET}",SUPABASE_JWT_KID="${SUPABASE_JWT_KID}",FIREBASE_PROJECT_ID="${PROJECT_ID}",MPESA_SERVICE_PROVIDER_CODE="${MPESA_SERVICE_PROVIDER_CODE:-000000}"

echo "=========================================================="
echo "✅ Déploiement terminé avec succès !"
echo "🌐 URL du service disponible dans les logs gcloud run ci-dessus."
echo "=========================================================="
