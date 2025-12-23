// Verify Ride OTP Edge Function
// Validates OTP for fraud prevention, moves ride to trip_started state

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

interface VerifyOtpRequest {
    booking_id: string;
    otp: string;
    lat?: number;
    lng?: number;
}

interface VerifyOtpResponse {
    success: boolean;
    data?: {
        booking_id: string;
        verified: boolean;
        new_status: string;
        trip_started_at: string;
    };
    error?: string;
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // Get auth token
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

        // Parse request
        const body: VerifyOtpRequest = await req.json();
        const { booking_id, otp, lat, lng } = body;

        if (!booking_id || !otp) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing booking_id or otp" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Use service role for operations
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const serviceClient = createClient(supabaseUrl, serviceRoleKey);

        // Get booking
        const { data: booking, error: bookingError } = await serviceClient
            .from("ride_bookings")
            .select("id, status, otp, driver_id, customer_id, pickup_lat, pickup_lng")
            .eq("id", booking_id)
            .single();

        if (bookingError || !booking) {
            return new Response(
                JSON.stringify({ success: false, error: "Booking not found" }),
                { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Verify user is the assigned driver
        if (booking.driver_id !== user.id) {
            return new Response(
                JSON.stringify({ success: false, error: "Not authorized: You are not the assigned driver" }),
                { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Check booking is in correct state
        if (booking.status !== "driver_arrived") {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: `Cannot verify OTP: booking status is '${booking.status}', expected 'driver_arrived'`,
                }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Verify OTP
        if (booking.otp !== otp) {
            // Log failed attempt
            await serviceClient.from("ride_events").insert({
                ride_booking_id: booking_id,
                event_type: "otp_verified",
                triggered_by: user.id,
                triggered_by_type: "driver",
                payload: { verified: false, reason: "invalid_otp" },
                lat: lat || booking.pickup_lat,
                lng: lng || booking.pickup_lng,
            });

            return new Response(
                JSON.stringify({ success: false, error: "Invalid OTP" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // OTP verified - start trip
        const tripStartedAt = new Date().toISOString();

        const { error: updateError } = await serviceClient
            .from("ride_bookings")
            .update({
                status: "trip_started",
                trip_started_at: tripStartedAt,
                updated_at: tripStartedAt,
            })
            .eq("id", booking_id);

        if (updateError) {
            return new Response(
                JSON.stringify({ success: false, error: `Update failed: ${updateError.message}` }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Update driver status to on_trip
        await serviceClient
            .from("driver_profiles")
            .update({
                status: "on_trip",
                updated_at: tripStartedAt,
            })
            .eq("id", user.id);

        // Log successful verification
        await serviceClient.from("ride_events").insert({
            ride_booking_id: booking_id,
            event_type: "otp_verified",
            triggered_by: user.id,
            triggered_by_type: "driver",
            payload: { verified: true },
            lat: lat || booking.pickup_lat,
            lng: lng || booking.pickup_lng,
        });

        // Log trip started
        await serviceClient.from("ride_events").insert({
            ride_booking_id: booking_id,
            event_type: "trip_started",
            triggered_by: user.id,
            triggered_by_type: "driver",
            payload: {},
            lat: lat || booking.pickup_lat,
            lng: lng || booking.pickup_lng,
        });

        const response: VerifyOtpResponse = {
            success: true,
            data: {
                booking_id,
                verified: true,
                new_status: "trip_started",
                trip_started_at: tripStartedAt,
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
