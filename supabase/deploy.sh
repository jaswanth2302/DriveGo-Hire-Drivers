#!/bin/bash
# Drivo Backend Deployment Script
# Deploy all Edge Functions to Supabase

set -e

PROJECT_REF="kgfscfqvymnclelcqwlh"

echo "🚀 Deploying Drivo Edge Functions..."
echo "Project: $PROJECT_REF"
echo ""

# Login (if not already logged in)
# npx supabase login --token sbp_f8bf262567fd0e7bfc3d9e8d097c1466ab92a503

# Link project
echo "📦 Linking project..."
npx supabase link --project-ref $PROJECT_REF

# Deploy all functions
echo ""
echo "📤 Deploying Edge Functions..."

FUNCTIONS=(
  "estimate-ride-fare"
  "create-ride-booking"
  "match-driver-for-ride"
  "driver-heartbeat"
  "update-ride-status"
  "verify-ride-otp"
  "finalize-ride-fare"
  "cancel-ride"
  "handle-scheduled-rides"
  "surge-pricing-worker"
  "cleanup-stale-sessions"
)

for func in "${FUNCTIONS[@]}"; do
  echo "  → Deploying $func..."
  npx supabase functions deploy $func --project-ref $PROJECT_REF --no-verify-jwt
done

echo ""
echo "✅ All functions deployed successfully!"
echo ""
echo "📋 Function Endpoints:"
echo "  Base URL: https://$PROJECT_REF.supabase.co/functions/v1/"
echo ""
for func in "${FUNCTIONS[@]}"; do
  echo "  • $func"
done

echo ""
echo "🔧 Next Steps:"
echo "  1. Run migrations/003_realtime_storage_cron.sql in Supabase SQL Editor"
echo "  2. Enable pg_cron extension in Database → Extensions"
echo "  3. Enable pg_net extension for HTTP calls from cron"
echo "  4. Set service_role_key in app.settings for cron auth"
echo ""
echo "Done! 🎉"
