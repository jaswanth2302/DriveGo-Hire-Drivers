// Surge Pricing Worker - Cron Job
// Runs every 5 minutes to calculate surge based on demand/supply

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

// Surge calculation rules
const SURGE_RULES = {
    // demand_supply_ratio: surge_multiplier
    thresholds: [
        { ratio: 3.0, surge: 2.0 },   // 3+ requests per driver = 2x surge
        { ratio: 2.0, surge: 1.5 },   // 2+ requests per driver = 1.5x surge
        { ratio: 1.5, surge: 1.3 },   // 1.5+ requests per driver = 1.3x surge
        { ratio: 1.2, surge: 1.1 },   // 1.2+ requests per driver = 1.1x surge
    ],
    minDrivers: 1,  // Minimum drivers to consider for surge
    validityMinutes: 10, // Surge valid for 10 minutes
};

interface SurgeResponse {
    success: boolean;
    data?: {
        zones_updated: number;
        zones: Array<{
            city_code: string;
            zone_id: string;
            surge_multiplier: number;
            active_requests: number;
            available_drivers: number;
        }>;
    };
    error?: string;
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

        if (!serviceRoleKey) {
            return new Response(
                JSON.stringify({ success: false, error: "Service role key not configured" }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const supabase = createClient(supabaseUrl, serviceRoleKey);
        const now = new Date();
        const fiveMinutesAgo = new Date(now.getTime() - 5 * 60 * 1000);

        // Get all active cities with recent activity
        const { data: cityCodes } = await supabase
            .from("profiles")
            .select("city_code")
            .not("city_code", "is", null);

        const uniqueCities = [...new Set(cityCodes?.map(c => c.city_code) || ["BLR"])];

        const surgeZones: Array<{
            city_code: string;
            zone_id: string;
            surge_multiplier: number;
            active_requests: number;
            available_drivers: number;
        }> = [];

        for (const cityCode of uniqueCities) {
            // Count active ride requests in this city (searching status)
            const { count: activeRequests } = await supabase
                .from("ride_bookings")
                .select("*", { count: "exact", head: true })
                .eq("status", "searching")
                .gte("requested_at", fiveMinutesAgo.toISOString());

            // Count available drivers in this city
            const { count: availableDrivers } = await supabase
                .from("driver_profiles")
                .select("*", { count: "exact", head: true })
                .eq("status", "online")
                .eq("city_code", cityCode);

            const requests = activeRequests || 0;
            const drivers = Math.max(availableDrivers || 0, SURGE_RULES.minDrivers);

            // Calculate demand/supply ratio
            const ratio = drivers > 0 ? requests / drivers : requests;

            // Determine surge multiplier
            let surgeMultiplier = 1.0;
            for (const threshold of SURGE_RULES.thresholds) {
                if (ratio >= threshold.ratio) {
                    surgeMultiplier = threshold.surge;
                    break;
                }
            }

            // Create/update surge zone
            const zoneId = `${cityCode}_default`;
            const validUntil = new Date(now.getTime() + SURGE_RULES.validityMinutes * 60 * 1000);

            // Upsert surge zone
            await supabase
                .from("surge_zones")
                .upsert({
                    city_code: cityCode,
                    zone_id: zoneId,
                    surge_multiplier: surgeMultiplier,
                    active_requests: requests,
                    available_drivers: drivers,
                    demand_supply_ratio: Math.round(ratio * 100) / 100,
                    valid_from: now.toISOString(),
                    valid_until: validUntil.toISOString(),
                    updated_at: now.toISOString(),
                }, {
                    onConflict: "city_code,zone_id",
                    ignoreDuplicates: false,
                });

            surgeZones.push({
                city_code: cityCode,
                zone_id: zoneId,
                surge_multiplier: surgeMultiplier,
                active_requests: requests,
                available_drivers: drivers,
            });
        }

        // Clean up expired surge zones
        await supabase
            .from("surge_zones")
            .delete()
            .lt("valid_until", fiveMinutesAgo.toISOString());

        const response: SurgeResponse = {
            success: true,
            data: {
                zones_updated: surgeZones.length,
                zones: surgeZones,
            },
        };

        return new Response(JSON.stringify(response), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    } catch (error) {
        console.error("Error:", error);
        return new Response(
            JSON.stringify({ success: false, error: error.message || "Internal server error" }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
});
