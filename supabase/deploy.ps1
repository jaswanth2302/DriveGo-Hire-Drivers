# Drivo Backend Deployment Script (Windows PowerShell)
# Deploy all Edge Functions to Supabase

$PROJECT_REF = "kgfscfqvymnclelcqwlh"

Write-Host "🚀 Deploying Drivo Edge Functions..." -ForegroundColor Cyan
Write-Host "Project: $PROJECT_REF"
Write-Host ""

# Link project
Write-Host "📦 Linking project..." -ForegroundColor Yellow
npx supabase link --project-ref $PROJECT_REF

# Deploy all functions
Write-Host ""
Write-Host "📤 Deploying Edge Functions..." -ForegroundColor Yellow

$functions = @(
    "estimate-ride-fare",
    "create-ride-booking",
    "match-driver-for-ride",
    "driver-heartbeat",
    "update-ride-status",
    "verify-ride-otp",
    "finalize-ride-fare",
    "cancel-ride",
    "handle-scheduled-rides",
    "surge-pricing-worker",
    "cleanup-stale-sessions"
)

foreach ($func in $functions) {
    Write-Host "  → Deploying $func..." -ForegroundColor Gray
    npx supabase functions deploy $func --project-ref $PROJECT_REF --no-verify-jwt
}

Write-Host ""
Write-Host "✅ All functions deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Function Endpoints:" -ForegroundColor Cyan
Write-Host "  Base URL: https://$PROJECT_REF.supabase.co/functions/v1/"
Write-Host ""
foreach ($func in $functions) {
    Write-Host "  • $func"
}

Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Run migrations/003_realtime_storage_cron.sql in Supabase SQL Editor"
Write-Host "  2. Enable pg_cron extension in Database → Extensions"
Write-Host "  3. Enable pg_net extension for HTTP calls from cron"
Write-Host "  4. Set service_role_key in app.settings for cron auth"
Write-Host ""
Write-Host "Done! 🎉" -ForegroundColor Green
