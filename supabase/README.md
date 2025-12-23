# Drivo Supabase Backend

This directory contains the PostgreSQL database schema for the Drivo Hire Driver service.

## Files

| File | Description |
|------|-------------|
| `schema.sql` | Complete database schema including tables, enums, indexes, RLS policies, triggers, and seed data |

## Quick Start

### Option 1: Using Supabase CLI

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Push the schema
supabase db push
```

### Option 2: Using Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **SQL Editor**
4. Paste the contents of `schema.sql`
5. Click **Run**

## Schema Overview

### Tables (25+)

- **Users & Authentication**: `users`, `user_kyc_documents`, `drivers`, `driver_kyc_documents`
- **Bookings**: `bookings`, `trip_stops`, `trip_return_info`, `return_tasks`, `live_billing`
- **Configuration**: `car_types`, `service_zones`, `city_return_fees`, `saved_locations`
- **Payments**: `payments`, `saved_payment_methods`, `driver_earnings`, `driver_bonuses`
- **Tracking**: `driver_location_history`, `trip_trail`, `safety_alerts`, `geofence_events`
- **System**: `ratings`, `notifications`, `support_tickets`, `audit_logs`

### Security

All tables have **Row Level Security (RLS)** enabled:
- Users can only access their own data
- Drivers can only view assigned bookings
- Service role has full access for backend operations
- Public read access for configuration tables

### Pricing Configuration

| Car Type | Price/Hour |
|----------|------------|
| Hatchback (Manual) | ₹199 |
| Sedan (Manual) | ₹209 |
| Compact SUV (Manual) | ₹219 |
| Mid SUV (Manual) | ₹229 |
| MPV (Manual) | ₹239 |
| Automatic variants | +₹20 |
| Electric | ₹259 |

### City Return Fees

| City | Fee |
|------|-----|
| Bangalore | ₹200 |
| Mumbai | ₹250 |
| Delhi | ₹200 |
| Chennai | ₹180 |
| Hyderabad | ₹180 |

## Flutter Integration

Add these environment variables to your `.env` file:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

Install the Supabase Flutter package:

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.3.0
```

Initialize in your app:

```dart
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL']!,
  anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
);
```

## Entity Relationships

```
┌─────────┐     ┌──────────┐     ┌─────────┐
│  users  │────▶│ bookings │◀────│ drivers │
└─────────┘     └──────────┘     └─────────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
  ┌──────────┐  ┌──────────┐  ┌──────────┐
  │trip_stops│  │live_bill │  │ payments │
  └──────────┘  │   ing    │  └──────────┘
                └──────────┘
```

## Maintenance

### Backup

Use Supabase's built-in backup or:

```bash
supabase db dump -f backup.sql
```

### Migrations

For schema changes, create migration files:

```bash
supabase migration new add_new_feature
```

## Support

For issues with the schema, check:
- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
