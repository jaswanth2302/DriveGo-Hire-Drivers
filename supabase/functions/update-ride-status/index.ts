// Update Ride Status Edge Function
// Enforces state machine transitions - rejects invalid state changes

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

// State machine: valid transitions
const VALID_TRANSITIONS: Record<string, string[]> = {
    idle: ["searching"],
    searching: ["driver_assigned", "cancelled_by_user", "auto_cancelled"],
    scheduled: ["searching", "cancelled_by_user"],
    driver_assigned: ["driver_en_route", "cancelled_by_user", "cancelled_by_driver"],
    driver_en_route: ["driver_arrived", "cancelled_by_user", "cancelled_by_driver"],
    driver_arrived: ["trip_started", "cancelled_by_user", "cancelled_by_driver"],
    trip_started: ["trip_in_progress", "cancelled_by_user", "cancelled_by_driver"],
    trip_in_progress: ["trip_completed", "cancelled_by_user", "cancelled_by_driver"],
    trip_completed: ["payment_completed"],
    payment_completed: [], // Terminal state
    cancelled_by_user: [], // Terminal state
    cancelled_by_driver: [], // Terminal state
    auto_cancelled: [], // Terminal state
};

// Map status to ride_event type
const STATUS_TO_EVENT: Record<string, string> = {
    searching: "driver_search_started",
    driver_assigned: "driver_assigned",
    driver_en_route: "driver_en_route",
    driver_arrived: "driver_arrived",
    trip_started: "trip_started",
    trip_in_progress: "trip_started", // Same event
    trip_completed: "trip_completed",
    payment_completed: "payment_completed",
    cancelled_by_user: "trip_cancelled",
    cancelled_by_driver: "trip_cancelled",
    auto_cancelled: "trip_cancelled",
};

interface UpdateStatusRequest {
    booking_id: string;
    new_status: string;
    lat?: number;
    lng?: number;
    metadata?: Record<string, unknown>;
}

interface UpdateStatusResponse {
    success: boolean;
    data?: {
        booking_id: string;
        old_status: string;
        new_status: string;
        updated_at: string;
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

        // Get authenticated user
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        if (userError || !user) {
            return new Response(
                JSON.stringify({ success: false, error: "Unauthorized: Invalid token" }),
                { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Parse request
        const body: UpdateStatusRequest = await req.json();
        const { booking_id, new_status, lat, lng, metadata } = body;

        if (!booking_id || !new_status) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing booking_id or new_status" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Use service role for operations
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const serviceClient = createClient(supabaseUrl, serviceRoleKey);

        // Get current booking
        const { data: booking, error: bookingError } = await serviceClient
            .from("ride_bookings")
            .select("id, status, customer_id, driver_id")
            .eq("id", booking_id)
            .single();

        if (bookingError || !booking) {
            return new Response(
                JSON.stringify({ success: false, error: "Booking not found" }),
                { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Verify user is participant (customer or driver)
        const isCustomer = booking.customer_id === user.id;
        const isDriver = booking.driver_id === user.id;

        if (!isCustomer && !isDriver) {
            return new Response(
                JSON.stringify({ success: false, error: "Not authorized for this booking" }),
                { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const currentStatus = booking.status;

        // Validate state transition
        const allowedNextStates = VALID_TRANSITIONS[currentStatus] || [];
        if (!allowedNextStates.includes(new_status)) {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: `Invalid transition: '${currentStatus}' → '${new_status}'. Allowed: [${allowedNextStates.join(", ")}]`,
                }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Build update object with timestamp for specific statuses
        const updateData: Record<string, unknown> = {
            status: new_status,
            updated_at: new Date().toISOString(),
        };

        // Set specific timestamps
        switch (new_status) {
            case "driver_arrived":
                updateData.driver_arrived_at = new Date().toISOString();
                break;
            case "trip_started":
                updateData.trip_started_at = new Date().toISOString();
                break;
            case "trip_completed":
                updateData.trip_completed_at = new Date().toISOString();
                break;
            case "cancelled_by_user":
            case "cancelled_by_driver":
            case "auto_cancelled":
                updateData.cancelled_at = new Date().toISOString();
                updateData.cancellation_reason = (metadata as Record<string, string>)?.reason || null;
                break;
        }

        // Update booking
        const { error: updateError } = await serviceClient
            .from("ride_bookings")
            .update(updateData)
            .eq("id", booking_id);

        if (updateError) {
            return new Response(
                JSON.stringify({ success: false, error: `Update failed: ${updateError.message}` }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Log ride event
        const eventType = STATUS_TO_EVENT[new_status] || "booking_created";
        await serviceClient.from("ride_events").insert({
            ride_booking_id: booking_id,
            event_type: eventType,
            triggered_by: user.id,
            triggered_by_type: isDriver ? "driver" : "customer",
            payload: {
                old_status: currentStatus,
                new_status: new_status,
                ...metadata,
            },
            lat: lat || null,
            lng: lng || null,
        });

        // If cancellation, free up the driver
        if (new_status.startsWith("cancelled") && booking.driver_id) {
            await serviceClient
                .from("driver_profiles")
                .update({
                    status: "online",
                    updated_at: new Date().toISOString(),
                })
                .eq("id", booking.driver_id)
                .eq("status", "busy");
        }

        const response: UpdateStatusResponse = {
            success: true,
            data: {
                booking_id,
                old_status: currentStatus,
                new_status,
                updated_at: updateData.updated_at as string,
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
