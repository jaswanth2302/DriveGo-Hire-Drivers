// Match Driver for Ride - Core matching algorithm
// Finds eligible drivers, pings sequentially with timeout, handles atomic assignment

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
        "authorization, x-client-info, apikey, content-type",
};

interface MatchRequest {
    booking_id: string;
    search_radius_km?: number;
    max_attempts?: number;
}

interface DriverCandidate {
    id: string;
    name: string;
    rating: number;
    distance_km: number;
    idle_minutes: number;
    acceptance_rate: number;
    matching_priority_score: number;
    current_lat: number;
    current_lng: number;
}

interface MatchResponse {
    success: boolean;
    data?: {
        matched: boolean;
        driver_id?: string;
        driver_name?: string;
        driver_rating?: number;
        eta_minutes?: number;
        attempts_made: number;
    };
    error?: string;
}

// Calculate distance using Haversine formula
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

// Get eligible drivers near pickup location
async function findEligibleDrivers(
    supabase: SupabaseClient,
    pickupLat: number,
    pickupLng: number,
    radiusKm: number,
    rideTypeId: string,
    cityCode: string
): Promise<DriverCandidate[]> {
    // Get online drivers with active sessions
    const { data: drivers, error } = await supabase
        .from("driver_profiles")
        .select(`
      id,
      name,
      rating,
      current_lat,
      current_lng,
      acceptance_rate,
      matching_priority_score,
      city_code,
      last_location_update
    `)
        .eq("status", "online")
        .eq("city_code", cityCode)
        .not("current_lat", "is", null)
        .not("current_lng", "is", null);

    if (error || !drivers) {
        console.error("Error fetching drivers:", error);
        return [];
    }

    // Filter by distance and calculate idle time
    const now = Date.now();
    const candidates: DriverCandidate[] = [];

    for (const driver of drivers) {
        const distance = haversineDistance(
            pickupLat,
            pickupLng,
            driver.current_lat,
            driver.current_lng
        );

        if (distance <= radiusKm) {
            // Calculate idle time from last location update
            const lastUpdate = driver.last_location_update
                ? new Date(driver.last_location_update).getTime()
                : now - 60000; // Default 1 min idle
            const idleMinutes = Math.max(0, (now - lastUpdate) / 60000);

            candidates.push({
                id: driver.id,
                name: driver.name || "Driver",
                rating: driver.rating || 4.5,
                distance_km: distance,
                idle_minutes: idleMinutes,
                acceptance_rate: driver.acceptance_rate || 100,
                matching_priority_score: driver.matching_priority_score || 50,
                current_lat: driver.current_lat,
                current_lng: driver.current_lng,
            });
        }
    }

    // Sort by matching priority score (highest first), then by distance (nearest first)
    candidates.sort((a, b) => {
        // Primary: priority score (higher is better)
        if (b.matching_priority_score !== a.matching_priority_score) {
            return b.matching_priority_score - a.matching_priority_score;
        }
        // Secondary: distance (lower is better)
        return a.distance_km - b.distance_km;
    });

    return candidates;
}

// Log match attempt
async function logMatchAttempt(
    supabase: SupabaseClient,
    bookingId: string,
    driverId: string,
    attemptOrder: number,
    distanceKm: number,
    etaMinutes: number
): Promise<string | null> {
    const expiresAt = new Date(Date.now() + 30000); // 30 second timeout

    const { data, error } = await supabase
        .from("ride_match_attempts")
        .insert({
            ride_booking_id: bookingId,
            driver_id: driverId,
            attempt_order: attemptOrder,
            distance_km: Math.round(distanceKm * 100) / 100,
            estimated_eta_minutes: etaMinutes,
            expires_at: expiresAt.toISOString(),
            response: "pending",
        })
        .select("id")
        .single();

    if (error) {
        console.error("Error logging match attempt:", error);
        return null;
    }

    return data.id;
}

// Atomic driver assignment using conditional update
async function assignDriver(
    supabase: SupabaseClient,
    bookingId: string,
    driverId: string
): Promise<boolean> {
    // Use conditional update to prevent race conditions
    // Only assign if status is still 'searching'
    const { data, error } = await supabase
        .from("ride_bookings")
        .update({
            driver_id: driverId,
            status: "driver_assigned",
            driver_assigned_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
        })
        .eq("id", bookingId)
        .eq("status", "searching") // Conditional: only if still searching
        .select()
        .single();

    if (error || !data) {
        console.error("Assignment failed (race condition or booking changed):", error);
        return false;
    }

    // Update driver status to busy
    await supabase
        .from("driver_profiles")
        .update({
            status: "busy",
            updated_at: new Date().toISOString(),
        })
        .eq("id", driverId)
        .eq("status", "online"); // Only if still online

    // Mark match attempt as assigned
    await supabase
        .from("ride_match_attempts")
        .update({
            was_assigned: true,
            response: "accepted",
            responded_at: new Date().toISOString(),
        })
        .eq("ride_booking_id", bookingId)
        .eq("driver_id", driverId)
        .eq("response", "pending");

    return true;
}

// Log ride event
async function logRideEvent(
    supabase: SupabaseClient,
    bookingId: string,
    eventType: string,
    driverId: string | null,
    payload: Record<string, unknown>
): Promise<void> {
    await supabase.from("ride_events").insert({
        ride_booking_id: bookingId,
        event_type: eventType,
        triggered_by: driverId,
        triggered_by_type: driverId ? "driver" : "system",
        payload,
    });
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const body: MatchRequest = await req.json();
        const { booking_id, search_radius_km = 3.0, max_attempts = 10 } = body;

        if (!booking_id) {
            return new Response(
                JSON.stringify({ success: false, error: "Missing booking_id" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Create service client (needs service role for cross-user operations)
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
        const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const supabase = createClient(supabaseUrl, serviceRoleKey);

        // Get booking details
        const { data: booking, error: bookingError } = await supabase
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

        // Verify booking is in searchable state
        if (booking.status !== "searching") {
            return new Response(
                JSON.stringify({
                    success: false,
                    error: `Cannot match: booking status is '${booking.status}', expected 'searching'`
                }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Get city code from customer profile
        const { data: profile } = await supabase
            .from("profiles")
            .select("city_code")
            .eq("id", booking.customer_id)
            .single();

        const cityCode = profile?.city_code || "BLR";

        // Find eligible drivers
        const candidates = await findEligibleDrivers(
            supabase,
            booking.pickup_lat,
            booking.pickup_lng,
            search_radius_km,
            booking.ride_type_id,
            cityCode
        );

        if (candidates.length === 0) {
            // No drivers found - log event and return
            await logRideEvent(supabase, booking_id, "driver_search_started", null, {
                search_radius_km,
                candidates_found: 0,
                result: "no_drivers_available",
            });

            return new Response(
                JSON.stringify({
                    success: true,
                    data: {
                        matched: false,
                        attempts_made: 0,
                    },
                } as MatchResponse),
                { headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // Try to match with drivers (first candidate that "accepts")
        // In production, this would be async with actual driver pings
        let attemptsMade = 0;

        for (const candidate of candidates.slice(0, max_attempts)) {
            attemptsMade++;

            // Calculate ETA (rough estimate: 2 min per km in city)
            const etaMinutes = Math.ceil(candidate.distance_km * 2);

            // Log match attempt
            await logMatchAttempt(
                supabase,
                booking_id,
                candidate.id,
                attemptsMade,
                candidate.distance_km,
                etaMinutes
            );

            // Log ping event
            await logRideEvent(supabase, booking_id, "driver_pinged", candidate.id, {
                attempt_order: attemptsMade,
                distance_km: candidate.distance_km,
                eta_minutes: etaMinutes,
            });

            // Simulate driver acceptance (in production, wait for response)
            // For demo: accept based on acceptance_rate probability
            const accepts = Math.random() * 100 < candidate.acceptance_rate;

            if (accepts) {
                // Try atomic assignment
                const assigned = await assignDriver(supabase, booking_id, candidate.id);

                if (assigned) {
                    // Log successful assignment
                    await logRideEvent(supabase, booking_id, "driver_assigned", candidate.id, {
                        driver_name: candidate.name,
                        driver_rating: candidate.rating,
                        distance_km: candidate.distance_km,
                        eta_minutes: etaMinutes,
                        attempts_made: attemptsMade,
                    });

                    return new Response(
                        JSON.stringify({
                            success: true,
                            data: {
                                matched: true,
                                driver_id: candidate.id,
                                driver_name: candidate.name,
                                driver_rating: candidate.rating,
                                eta_minutes: etaMinutes,
                                attempts_made: attemptsMade,
                            },
                        } as MatchResponse),
                        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
                    );
                }
            } else {
                // Mark as rejected/timeout
                await supabase
                    .from("ride_match_attempts")
                    .update({
                        response: "rejected",
                        responded_at: new Date().toISOString(),
                    })
                    .eq("ride_booking_id", booking_id)
                    .eq("driver_id", candidate.id)
                    .eq("response", "pending");

                await logRideEvent(supabase, booking_id, "driver_rejected", candidate.id, {
                    attempt_order: attemptsMade,
                });
            }
        }

        // No driver matched after all attempts
        return new Response(
            JSON.stringify({
                success: true,
                data: {
                    matched: false,
                    attempts_made: attemptsMade,
                },
            } as MatchResponse),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    } catch (error) {
        console.error("Error:", error);
        return new Response(
            JSON.stringify({ success: false, error: error.message || "Internal server error" }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
});
