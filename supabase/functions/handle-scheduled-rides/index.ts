// Handle Scheduled Rides - Cron Job
// Runs every 5 minutes to match drivers for upcoming scheduled rides

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

interface ScheduledRidesResponse {
    success: boolean;
    data?: {
        rides_processed: number;
        rides_matched: number;
        rides_failed: number;
        details: Array<{
            booking_id: string;
            status: string;
            matched: boolean;
        }>;
    };
    error?: string;
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        // This function should be called by cron/scheduler with service role
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

        if (!serviceRoleKey) {
            return new Response(
                JSON.stringify({ success: false, error: "Service role key not configured" }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const supabase = createClient(supabaseUrl, serviceRoleKey);

        // Find rides scheduled within the next 30 minutes that haven't been matched yet
        const now = new Date();
        const thirtyMinutesFromNow = new Date(now.getTime() + 30 * 60 * 1000);

        const { data: scheduledRides, error: fetchError } = await supabase
            .from("ride_bookings")
            .select("id, scheduled_time, customer_id, scheduled_match_retry_count")
            .eq("status", "scheduled")
            .eq("timing_mode", "scheduled")
            .lte("scheduled_time", thirtyMinutesFromNow.toISOString())
            .lt("scheduled_match_retry_count", 3) // Max 3 retries
            .order("scheduled_time", { ascending: true })
            .limit(20);

        if (fetchError) {
            return new Response(
                JSON.stringify({ success: false, error: `Fetch error: ${fetchError.message}` }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        if (!scheduledRides || scheduledRides.length === 0) {
            return new Response(
                JSON.stringify({
                    success: true,
                    data: {
                        rides_processed: 0,
                        rides_matched: 0,
                        rides_failed: 0,
                        details: [],
                    },
                }),
                { headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const results: Array<{ booking_id: string; status: string; matched: boolean }> = [];
        let matchedCount = 0;
        let failedCount = 0;

        for (const ride of scheduledRides) {
            try {
                // Update to searching status
                await supabase
                    .from("ride_bookings")
                    .update({
                        status: "searching",
                        scheduled_match_attempted_at: now.toISOString(),
                        scheduled_match_retry_count: (ride.scheduled_match_retry_count || 0) + 1,
                        updated_at: now.toISOString(),
                    })
                    .eq("id", ride.id);

                // Log event
                await supabase.from("ride_events").insert({
                    ride_booking_id: ride.id,
                    event_type: "driver_search_started",
                    triggered_by_type: "system",
                    payload: {
                        trigger: "scheduled_ride_cron",
                        scheduled_time: ride.scheduled_time,
                        retry_count: (ride.scheduled_match_retry_count || 0) + 1,
                    },
                });

                // Call matching function internally
                const matchResponse = await fetch(`${supabaseUrl}/functions/v1/match-driver-for-ride`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "Authorization": `Bearer ${serviceRoleKey}`,
                    },
                    body: JSON.stringify({
                        booking_id: ride.id,
                        search_radius_km: 5.0,
                        max_attempts: 10,
                    }),
                });

                const matchResult = await matchResponse.json();

                if (matchResult.success && matchResult.data?.matched) {
                    matchedCount++;
                    results.push({ booking_id: ride.id, status: "matched", matched: true });
                } else {
                    failedCount++;
                    results.push({ booking_id: ride.id, status: "no_driver", matched: false });

                    // Revert to scheduled if no driver found (for retry)
                    await supabase
                        .from("ride_bookings")
                        .update({
                            status: "scheduled",
                            updated_at: now.toISOString(),
                        })
                        .eq("id", ride.id)
                        .eq("status", "searching");
                }
            } catch (e) {
                console.error(`Error processing ride ${ride.id}:`, e);
                failedCount++;
                results.push({ booking_id: ride.id, status: "error", matched: false });
            }
        }

        const response: ScheduledRidesResponse = {
            success: true,
            data: {
                rides_processed: scheduledRides.length,
                rides_matched: matchedCount,
                rides_failed: failedCount,
                details: results,
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
