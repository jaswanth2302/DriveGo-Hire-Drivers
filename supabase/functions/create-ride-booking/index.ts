// Create Ride Booking Edge Function
// Implements the first step of the ride state machine: IDLE -> SEARCHING

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

// Valid ride states (matches frontend RideState enum and DB ride_booking_status)
const VALID_RIDE_STATUSES = [
    "idle",
    "searching",
    "driver_assigned",
    "driver_en_route",
    "driver_arrived",
    "trip_started",
    "trip_in_progress",
    "trip_completed",
    "cancelled_by_user",
    "cancelled_by_driver",
    "auto_cancelled",
];

interface CreateBookingRequest {
    // Location
    pickup_address: string;
    pickup_short_name?: string;
    pickup_lat: number;
    pickup_lng: number;
    drop_address: string;
    drop_short_name?: string;
    drop_lat: number;
    drop_lng: number;

    // Ride details
    ride_type_id: string;
    timing_mode: "now" | "tomorrow" | "scheduled";
    scheduled_time?: string; // ISO datetime

    // Route info (from estimate)
    distance_km: number;
    duration_minutes: number;
    estimated_fare: number;
    surge_multiplier?: number;
    route_polyline?: string;

    // Payment
    payment_method?: string;
}

interface CreateBookingResponse {
    success: boolean;
    data?: {
        booking_id: string;
        status: string;
        otp: string;
        created_at: string;
    };
    error?: string;
}

// Generate 4-digit OTP
function generateOtp(): string {
    return String(Math.floor(1000 + Math.random() * 9000));
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // Get auth token from header
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing Authorization header" }),
                { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Create authenticated Supabase client
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
        const supabase = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } },
        });

        // Get authenticated user
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        if (userError || !user) {
            return new Response(
                JSON.stringify({ success: false, error: "Unauthorized: Invalid token" }),
                { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Parse request body
        const body: CreateBookingRequest = await req.json();

        // Validate required fields
        const requiredFields = [
            "pickup_address", "pickup_lat", "pickup_lng",
            "drop_address", "drop_lat", "drop_lng",
            "ride_type_id", "timing_mode", "distance_km", "duration_minutes", "estimated_fare"
        ];

        for (const field of requiredFields) {
            if (body[field as keyof CreateBookingRequest] === undefined) {
                return new Response(
                    JSON.stringify({ success: false, error: `Missing required field: ${field}` }),
                    { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
                );
            }
        }

        // Generate OTP for ride verification
        const otp = generateOtp();

        // Determine initial status based on timing mode
        const initialStatus = body.timing_mode === "now" ? "searching" : "scheduled";

        // Insert into ride_bookings table
        const { data: booking, error: insertError } = await supabase
            .from("ride_bookings")
            .insert({
                customer_id: user.id,
                ride_type_id: body.ride_type_id,
                status: initialStatus,
                timing_mode: body.timing_mode,
                scheduled_time: body.scheduled_time || null,

                // Pickup location
                pickup_address: body.pickup_address,
                pickup_short_name: body.pickup_short_name || null,
                pickup_lat: body.pickup_lat,
                pickup_lng: body.pickup_lng,

                // Drop location
                drop_address: body.drop_address,
                drop_short_name: body.drop_short_name || null,
                drop_lat: body.drop_lat,
                drop_lng: body.drop_lng,

                // Route & fare
                distance_km: body.distance_km,
                duration_minutes: Math.round(body.duration_minutes),
                estimated_fare: body.estimated_fare,
                surge_multiplier: body.surge_multiplier || 1.0,
                route_polyline: body.route_polyline || null,

                // Payment & OTP
                payment_method: body.payment_method || "cash",
                otp: otp,

                // Timestamps
                requested_at: new Date().toISOString(),
            })
            .select()
            .single();

        if (insertError) {
            console.error("Insert error:", insertError);
            return new Response(
                JSON.stringify({ success: false, error: `Database error: ${insertError.message}` }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Log ride event
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        if (serviceRoleKey) {
            const serviceClient = createClient(supabaseUrl, serviceRoleKey);
            await serviceClient.from("ride_events").insert({
                ride_booking_id: booking.id,
                event_type: "booking_created",
                triggered_by: user.id,
                triggered_by_type: "customer",
                payload: {
                    ride_type_id: body.ride_type_id,
                    timing_mode: body.timing_mode,
                    estimated_fare: body.estimated_fare,
                    distance_km: body.distance_km,
                },
                lat: body.pickup_lat,
                lng: body.pickup_lng,
            });

            // If immediate booking, also log search started
            if (body.timing_mode === "now") {
                await serviceClient.from("ride_events").insert({
                    ride_booking_id: booking.id,
                    event_type: "driver_search_started",
                    triggered_by_type: "system",
                    payload: { search_radius_km: 3.0 },
                    lat: body.pickup_lat,
                    lng: body.pickup_lng,
                });
            }
        }

        const response: CreateBookingResponse = {
            success: true,
            data: {
                booking_id: booking.id,
                status: booking.status,
                otp: otp,
                created_at: booking.created_at,
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
