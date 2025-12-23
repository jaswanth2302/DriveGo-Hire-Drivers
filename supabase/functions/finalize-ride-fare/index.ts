// Finalize Ride Fare Edge Function
// Calculates actual fare after trip completion, creates payment record

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

// Ride type pricing (same as estimate function)
const RIDE_TYPES: Record<string, { per_km: number; per_min: number; min_fare: number }> = {
    bike: { per_km: 8, per_min: 1, min_fare: 30 },
    auto: { per_km: 12, per_min: 1.5, min_fare: 40 },
    mini: { per_km: 14, per_min: 2, min_fare: 70 },
    sedan: { per_km: 18, per_min: 2.5, min_fare: 100 },
    suv: { per_km: 22, per_min: 3, min_fare: 150 },
};

interface FinalizeRequest {
    booking_id: string;
    actual_distance_km?: number;
    actual_duration_minutes?: number;
    tip_amount?: number;
    lat?: number;
    lng?: number;
}

interface FinalizeResponse {
    success: boolean;
    data?: {
        booking_id: string;
        estimated_fare: number;
        final_fare: number;
        tip_amount: number;
        total_amount: number;
        payment_id: string;
        status: string;
    };
    error?: string;
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing Authorization header" }),
                { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
        const supabase = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } },
        });

        const { data: { user }, error: userError } = await supabase.auth.getUser();
        if (userError || !user) {
            return new Response(
                JSON.stringify({ success: false, error: "Unauthorized" }),
                { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const body: FinalizeRequest = await req.json();
        const { booking_id, actual_distance_km, actual_duration_minutes, tip_amount = 0, lat, lng } = body;

        if (!booking_id) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing booking_id" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const serviceClient = createClient(supabaseUrl, serviceRoleKey);

        // Get booking
        const { data: booking, error: bookingError } = await serviceClient
            .from("ride_bookings")
            .select("*")
            .eq("id", booking_id)
            .single();

        if (bookingError || !booking) {
            return new Response(
                JSON.stringify({ success: false, error: "Booking not found" }),
                { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Verify user is participant
        if (booking.customer_id !== user.id && booking.driver_id !== user.id) {
            return new Response(
                JSON.stringify({ success: false, error: "Not authorized for this booking" }),
                { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Verify booking is completed
        if (booking.status !== "trip_completed" && booking.status !== "trip_in_progress") {
            return new Response(
                JSON.stringify({ success: false, error: `Cannot finalize: status is '${booking.status}'` }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Calculate actual fare
        const rideType = RIDE_TYPES[booking.ride_type_id] || RIDE_TYPES["mini"];
        const distance = actual_distance_km || booking.distance_km || 0;
        const duration = actual_duration_minutes || booking.duration_minutes || 0;
        const surge = booking.surge_multiplier || 1.0;

        let finalFare = (rideType.per_km * distance + rideType.per_min * duration) * surge;
        finalFare = Math.max(finalFare, rideType.min_fare);
        finalFare = Math.round(finalFare);

        const totalAmount = finalFare + (tip_amount || 0);

        // Update booking with final fare
        await serviceClient
            .from("ride_bookings")
            .update({
                final_fare: finalFare,
                status: "trip_completed",
                trip_completed_at: booking.trip_completed_at || new Date().toISOString(),
                updated_at: new Date().toISOString(),
            })
            .eq("id", booking_id);

        // Create payment record
        const { data: payment, error: paymentError } = await serviceClient
            .from("payments")
            .insert({
                booking_id: booking_id,
                user_id: booking.customer_id,
                amount: totalAmount,
                method: booking.payment_method || "cash",
                status: booking.payment_method === "cash" ? "pending" : "processing",
            })
            .select("id")
            .single();

        if (paymentError) {
            console.error("Payment creation error:", paymentError);
        }

        // Free up driver
        if (booking.driver_id) {
            await serviceClient
                .from("driver_profiles")
                .update({
                    status: "online",
                    updated_at: new Date().toISOString(),
                })
                .eq("id", booking.driver_id);
        }

        // Log event
        await serviceClient.from("ride_events").insert({
            ride_booking_id: booking_id,
            event_type: "trip_completed",
            triggered_by: user.id,
            triggered_by_type: booking.driver_id === user.id ? "driver" : "customer",
            payload: {
                estimated_fare: booking.estimated_fare,
                final_fare: finalFare,
                tip_amount: tip_amount,
                actual_distance_km: distance,
                actual_duration_minutes: duration,
            },
            lat: lat || booking.drop_lat,
            lng: lng || booking.drop_lng,
        });

        const response: FinalizeResponse = {
            success: true,
            data: {
                booking_id,
                estimated_fare: booking.estimated_fare,
                final_fare: finalFare,
                tip_amount: tip_amount || 0,
                total_amount: totalAmount,
                payment_id: payment?.id || "pending",
                status: "trip_completed",
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
