// Cancel Ride Edge Function
// Handles cancellations with fee calculation and driver release

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

// Cancellation fee rules
const CANCELLATION_RULES = {
    // Status: { canCancel, feePercent, customerCanCancel, driverCanCancel }
    searching: { canCancel: true, feePercent: 0, customerCanCancel: true, driverCanCancel: false },
    scheduled: { canCancel: true, feePercent: 0, customerCanCancel: true, driverCanCancel: false },
    driver_assigned: { canCancel: true, feePercent: 0, customerCanCancel: true, driverCanCancel: true },
    driver_en_route: { canCancel: true, feePercent: 10, customerCanCancel: true, driverCanCancel: true },
    driver_arrived: { canCancel: true, feePercent: 20, customerCanCancel: true, driverCanCancel: true },
    trip_started: { canCancel: false, feePercent: 50, customerCanCancel: false, driverCanCancel: false },
    trip_in_progress: { canCancel: false, feePercent: 100, customerCanCancel: false, driverCanCancel: false },
    trip_completed: { canCancel: false, feePercent: 100, customerCanCancel: false, driverCanCancel: false },
};

interface CancelRequest {
    booking_id: string;
    reason?: string;
    lat?: number;
    lng?: number;
}

interface CancelResponse {
    success: boolean;
    data?: {
        booking_id: string;
        old_status: string;
        new_status: string;
        cancellation_fee: number;
        cancelled_at: string;
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

        const body: CancelRequest = await req.json();
        const { booking_id, reason, lat, lng } = body;

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

        // Determine user role
        const isCustomer = booking.customer_id === user.id;
        const isDriver = booking.driver_id === user.id;

        if (!isCustomer && !isDriver) {
            return new Response(
                JSON.stringify({ success: false, error: "Not authorized for this booking" }),
                { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Check cancellation rules
        const rules = CANCELLATION_RULES[booking.status as keyof typeof CANCELLATION_RULES];

        if (!rules) {
            return new Response(
                JSON.stringify({ success: false, error: `Cannot cancel: unknown status '${booking.status}'` }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        if (!rules.canCancel) {
            return new Response(
                JSON.stringify({ success: false, error: `Cannot cancel: ride is already in progress` }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        if (isCustomer && !rules.customerCanCancel) {
            return new Response(
                JSON.stringify({ success: false, error: `Customer cannot cancel at this stage` }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        if (isDriver && !rules.driverCanCancel) {
            return new Response(
                JSON.stringify({ success: false, error: `Driver cannot cancel at this stage` }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Calculate cancellation fee
        const estimatedFare = booking.estimated_fare || 0;
        const cancellationFee = Math.round((estimatedFare * rules.feePercent) / 100);

        // Determine new status
        const newStatus = isDriver ? "cancelled_by_driver" : "cancelled_by_user";
        const cancelledAt = new Date().toISOString();

        // Update booking
        await serviceClient
            .from("ride_bookings")
            .update({
                status: newStatus,
                cancelled_at: cancelledAt,
                cancellation_reason: reason || null,
                final_fare: cancellationFee > 0 ? cancellationFee : null,
                updated_at: cancelledAt,
            })
            .eq("id", booking_id);

        // Free up driver
        if (booking.driver_id) {
            await serviceClient
                .from("driver_profiles")
                .update({
                    status: "online",
                    updated_at: cancelledAt,
                })
                .eq("id", booking.driver_id);

            // Update driver cancellation metrics if driver cancelled
            if (isDriver) {
                await serviceClient.rpc("increment_driver_cancellations", {
                    driver_id: booking.driver_id
                }).catch(() => {
                    // RPC might not exist, handled gracefully
                });
            }
        }

        // Log cancellation event
        await serviceClient.from("ride_events").insert({
            ride_booking_id: booking_id,
            event_type: "trip_cancelled",
            triggered_by: user.id,
            triggered_by_type: isDriver ? "driver" : "customer",
            payload: {
                old_status: booking.status,
                reason: reason || "no reason provided",
                cancellation_fee: cancellationFee,
                cancelled_by: isDriver ? "driver" : "customer",
            },
            lat: lat || booking.pickup_lat,
            lng: lng || booking.pickup_lng,
        });

        // Create cancellation fee payment if applicable
        if (cancellationFee > 0) {
            await serviceClient.from("payments").insert({
                booking_id: booking_id,
                user_id: booking.customer_id,
                amount: cancellationFee,
                method: booking.payment_method || "cash",
                status: "pending",
            });
        }

        const response: CancelResponse = {
            success: true,
            data: {
                booking_id,
                old_status: booking.status,
                new_status: newStatus,
                cancellation_fee: cancellationFee,
                cancelled_at: cancelledAt,
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
