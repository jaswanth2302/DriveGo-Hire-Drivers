// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

interface FareEstimateRequest {
    pickup_lat: number;
    pickup_lng: number;
    drop_lat: number;
    drop_lng: number;
    ride_type_id: string;
    city_code?: string;
}

interface FareEstimateResponse {
    success: boolean;
    data?: {
        ride_type_id: string;
        ride_type_name: string;
        distance_km: number;
        duration_minutes: number;
        base_fare: number;
        distance_charge: number;
        time_charge: number;
        surge_multiplier: number;
        surge_charge: number;
        estimated_fare: number;
        min_fare: number;
        currency: string;
    };
    error?: string;
}

// Ride type pricing configuration (matches frontend ride_models.dart)
const RIDE_TYPES: Record<
    string,
    {
        name: string;
        base_fare: number;
        per_km: number;
        per_min: number;
        min_fare: number;
    }
> = {
    bike: { name: "Bike", base_fare: 20, per_km: 8, per_min: 1, min_fare: 30 },
    auto: { name: "Auto", base_fare: 30, per_km: 12, per_min: 1.5, min_fare: 40 },
    mini: { name: "Mini", base_fare: 50, per_km: 14, per_min: 2, min_fare: 70 },
    sedan: {
        name: "Sedan",
        base_fare: 80,
        per_km: 18,
        per_min: 2.5,
        min_fare: 100,
    },
    suv: { name: "SUV", base_fare: 120, per_km: 22, per_min: 3, min_fare: 150 },
};

// Calculate distance using Haversine formula (fallback if routing fails)
function haversineDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
): number {
    const R = 6371; // Earth's radius in km
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

// Get route from OSRM (public demo server)
async function getRoute(
    pickupLat: number,
    pickupLng: number,
    dropLat: number,
    dropLng: number
): Promise<{ distance_km: number; duration_minutes: number } | null> {
    try {
        const coords = `${pickupLng},${pickupLat};${dropLng},${dropLat}`;
        const url = `https://router.project-osrm.org/route/v1/driving/${coords}?overview=false`;

        const response = await fetch(url);
        if (response.ok) {
            const data = await response.json();
            if (data.code === "Ok" && data.routes && data.routes.length > 0) {
                const route = data.routes[0];
                return {
                    distance_km: route.distance / 1000,
                    duration_minutes: route.duration / 60,
                };
            }
        }
        return null;
    } catch (e) {
        console.error("OSRM routing error:", e);
        return null;
    }
}

// Get surge multiplier for location
async function getSurgeMultiplier(
    supabase: ReturnType<typeof createClient>,
    lat: number,
    lng: number,
    cityCode: string
): Promise<number> {
    try {
        // Query active surge zones
        const { data } = await supabase
            .from("surge_zones")
            .select("surge_multiplier")
            .eq("city_code", cityCode)
            .gte("valid_until", new Date().toISOString())
            .order("surge_multiplier", { ascending: false })
            .limit(1);

        if (data && data.length > 0) {
            return data[0].surge_multiplier;
        }
        return 1.0; // No surge
    } catch (e) {
        console.error("Surge lookup error:", e);
        return 1.0;
    }
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const body: FareEstimateRequest = await req.json();
        const { pickup_lat, pickup_lng, drop_lat, drop_lng, ride_type_id, city_code = "BLR" } = body;

        // Validate inputs
        if (!pickup_lat || !pickup_lng || !drop_lat || !drop_lng || !ride_type_id) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: "Missing required fields: pickup_lat, pickup_lng, drop_lat, drop_lng, ride_type_id",
                } as FareEstimateResponse),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Get ride type config
        const rideType = RIDE_TYPES[ride_type_id];
        if (!rideType) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: `Invalid ride_type_id: ${ride_type_id}. Valid options: ${Object.keys(RIDE_TYPES).join(", ")}`,
                } as FareEstimateResponse),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Get route (distance & duration)
        let routeData = await getRoute(pickup_lat, pickup_lng, drop_lat, drop_lng);

        // Fallback to Haversine if routing fails
        if (!routeData) {
            const straightLineDistance = haversineDistance(pickup_lat, pickup_lng, drop_lat, drop_lng);
            // Estimate road distance as 1.4x straight line, duration at 25 km/h avg city speed
            routeData = {
                distance_km: straightLineDistance * 1.4,
                duration_minutes: (straightLineDistance * 1.4 * 60) / 25,
            };
        }

        // Create Supabase client for surge lookup
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
        const supabase = createClient(supabaseUrl, supabaseKey);

        // Get surge multiplier
        const surgeMultiplier = await getSurgeMultiplier(supabase, pickup_lat, pickup_lng, city_code);

        // Calculate fare components (matches frontend RideType.calculateFare)
        const distanceCharge = rideType.per_km * routeData.distance_km;
        const timeCharge = rideType.per_min * routeData.duration_minutes;
        const baseFare = rideType.base_fare;
        const subtotal = baseFare + distanceCharge + timeCharge;
        const surgeCharge = subtotal * (surgeMultiplier - 1);
        let estimatedFare = subtotal * surgeMultiplier;

        // Apply minimum fare
        if (estimatedFare < rideType.min_fare) {
            estimatedFare = rideType.min_fare;
        }

        // Round to nearest rupee
        estimatedFare = Math.round(estimatedFare);

        const response: FareEstimateResponse = {
            success: true,
            data: {
                ride_type_id,
                ride_type_name: rideType.name,
                distance_km: Math.round(routeData.distance_km * 10) / 10,
                duration_minutes: Math.round(routeData.duration_minutes),
                base_fare: baseFare,
                distance_charge: Math.round(distanceCharge),
                time_charge: Math.round(timeCharge),
                surge_multiplier: surgeMultiplier,
                surge_charge: Math.round(surgeCharge),
                estimated_fare: estimatedFare,
                min_fare: rideType.min_fare,
                currency: "INR",
            },
        };

        return new Response(JSON.stringify(response), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    } catch (error) {
        console.error("Error:", error);
        return new Response(
            JSON.stringify({
                success: false,
                error: error.message || "Internal server error",
            } as FareEstimateResponse),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
});
