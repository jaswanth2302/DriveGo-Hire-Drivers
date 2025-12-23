// Driver Heartbeat Edge Function
// Updates driver location and session, keeps them active in the system

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

interface HeartbeatRequest {
    lat: number;
    lng: number;
    heading?: number;
    speed?: number;
    accuracy?: number;
    battery_level?: number;
    app_version?: string;
}

interface HeartbeatResponse {
    success: boolean;
    data?: {
        session_id: string;
        status: string;
        active_booking_id?: string;
    };
    error?: string;
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

        // Get authenticated user (driver)
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        if (userError || !user) {
            return new Response(
                JSON.stringify({ success: false, error: "Unauthorized: Invalid token" }),
                { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const driverId = user.id;

        // Parse request body
        const body: HeartbeatRequest = await req.json();
        const { lat, lng, heading, speed, accuracy, battery_level, app_version } = body;

        if (!lat || !lng) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing lat/lng coordinates" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const now = new Date().toISOString();

        // Use service role for cross-table operations
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const serviceClient = createClient(supabaseUrl, serviceRoleKey);

        // 1. Update driver_profiles with current location
        const { data: driverProfile, error: profileError } = await serviceClient
            .from("driver_profiles")
            .update({
                current_lat: lat,
                current_lng: lng,
                current_heading: heading || null,
                last_location_update: now,
                updated_at: now,
            })
            .eq("id", driverId)
            .select("status, city_code")
            .single();

        if (profileError) {
            console.error("Profile update error:", profileError);
            return new Response(
                JSON.stringify({ success: false, error: "Driver profile not found" }),
                { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // 2. Update or create driver session
        // Find active session (no ended_at)
        const { data: existingSession } = await serviceClient
            .from("driver_sessions")
            .select("id")
            .eq("driver_id", driverId)
            .is("ended_at", null)
            .single();

        let sessionId: string;

        if (existingSession) {
            // Update existing session
            await serviceClient
                .from("driver_sessions")
                .update({
                    last_heartbeat: now,
                    last_battery_level: battery_level || null,
                    app_version: app_version || null,
                    updated_at: now,
                })
                .eq("id", existingSession.id);

            sessionId = existingSession.id;
        } else {
            // Create new session (driver just came online)
            const { data: newSession, error: sessionError } = await serviceClient
                .from("driver_sessions")
                .insert({
                    driver_id: driverId,
                    started_at: now,
                    last_heartbeat: now,
                    start_lat: lat,
                    start_lng: lng,
                    city_code: driverProfile.city_code || "BLR",
                    app_version: app_version || null,
                    last_battery_level: battery_level || null,
                })
                .select("id")
                .single();

            if (sessionError) {
                console.error("Session creation error:", sessionError);
            }

            sessionId = newSession?.id || "unknown";

            // Set driver status to online if not already
            if (driverProfile.status === "offline") {
                await serviceClient
                    .from("driver_profiles")
                    .update({
                        status: "online",
                        updated_at: now,
                    })
                    .eq("id", driverId);
            }
        }

        // 3. Log to driver_location_history (if on active trip, include booking_id)
        // Check for active booking
        const { data: activeBooking } = await serviceClient
            .from("ride_bookings")
            .select("id")
            .eq("driver_id", driverId)
            .in("status", ["driver_assigned", "driver_en_route", "driver_arrived", "trip_started", "trip_in_progress"])
            .single();

        // Insert location history (sampled - only if driver is on trip or every few calls)
        if (activeBooking) {
            await serviceClient
                .from("driver_location_history")
                .insert({
                    driver_id: driverId,
                    booking_id: activeBooking.id,
                    lat,
                    lng,
                    heading: heading || null,
                    speed: speed || null,
                    accuracy: accuracy || null,
                    recorded_at: now,
                });
        }

        const response: HeartbeatResponse = {
            success: true,
            data: {
                session_id: sessionId,
                status: driverProfile.status,
                active_booking_id: activeBooking?.id || undefined,
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
