// Cleanup Stale Sessions - Cron Job
// Runs every 2 minutes to end inactive driver sessions

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

interface CleanupResponse {
    success: boolean;
    data?: {
        sessions_ended: number;
        drivers_set_offline: number;
        bookings_auto_cancelled: number;
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
        const staleThreshold = new Date(now.getTime() - 5 * 60 * 1000); // 5 minutes

        let sessionsEnded = 0;
        let driversSetOffline = 0;
        let bookingsAutoCancelled = 0;

        // 1. End stale driver sessions
        const { data: staleSessions } = await supabase
            .from("driver_sessions")
            .select("id, driver_id")
            .is("ended_at", null)
            .lt("last_heartbeat", staleThreshold.toISOString());

        if (staleSessions && staleSessions.length > 0) {
            const sessionIds = staleSessions.map(s => s.id);
            const driverIds = staleSessions.map(s => s.driver_id);

            // End the sessions
            await supabase
                .from("driver_sessions")
                .update({
                    ended_at: now.toISOString(),
                    end_reason: "inactivity_timeout",
                    updated_at: now.toISOString(),
                })
                .in("id", sessionIds);

            sessionsEnded = staleSessions.length;

            // Set drivers offline
            const { count } = await supabase
                .from("driver_profiles")
                .update({
                    status: "offline",
                    updated_at: now.toISOString(),
                })
                .in("id", driverIds)
                .neq("status", "on_trip"); // Don't offline drivers on active trips

            driversSetOffline = count || 0;
        }

        // 2. Auto-cancel stale "searching" bookings (> 10 minutes)
        const searchingThreshold = new Date(now.getTime() - 10 * 60 * 1000);

        const { data: staleBookings } = await supabase
            .from("ride_bookings")
            .select("id, customer_id")
            .eq("status", "searching")
            .eq("timing_mode", "now")
            .lt("requested_at", searchingThreshold.toISOString());

        if (staleBookings && staleBookings.length > 0) {
            for (const booking of staleBookings) {
                // Auto-cancel
                await supabase
                    .from("ride_bookings")
                    .update({
                        status: "auto_cancelled",
                        cancelled_at: now.toISOString(),
                        cancellation_reason: "No driver found within timeout period",
                        updated_at: now.toISOString(),
                    })
                    .eq("id", booking.id);

                // Log event
                await supabase.from("ride_events").insert({
                    ride_booking_id: booking.id,
                    event_type: "trip_cancelled",
                    triggered_by_type: "system",
                    payload: {
                        reason: "auto_cancelled_no_driver",
                        timeout_minutes: 10,
                    },
                });

                bookingsAutoCancelled++;
            }
        }

        // 3. Timeout pending match attempts
        const matchTimeout = new Date(now.getTime() - 30 * 1000); // 30 seconds

        await supabase
            .from("ride_match_attempts")
            .update({
                response: "timeout",
                responded_at: now.toISOString(),
            })
            .eq("response", "pending")
            .lt("expires_at", now.toISOString());

        const response: CleanupResponse = {
            success: true,
            data: {
                sessions_ended: sessionsEnded,
                drivers_set_offline: driversSetOffline,
                bookings_auto_cancelled: bookingsAutoCancelled,
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
