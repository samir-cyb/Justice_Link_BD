// supabase/functions/emergency-push/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Simple FCM HTTP API (no admin SDK needed for basic push)
async function sendFCM(token: string, title: string, body: string, data: any) {
  const serverKey = Deno.env.get("FCM_SERVER_KEY"); // From Firebase Console

  const response = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `key=${serverKey}`,
    },
    body: JSON.stringify({
      to: token,
      notification: {
        title: title,
        body: body,
        sound: "emergency_alarm",
        priority: "high",
      },
      data: data,
      android: {
        priority: "high",
        notification: {
          channelId: "emergency_fcm_channel",
          fullScreenIntent: true,
          priority: "max",
        },
      },
    }),
  });

  return response.json();
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { emergency_id, user_id, type, lat, lng } = await req.json();

    console.log('Emergency push for:', emergency_id);
    console.log('Location:', lat, lng);

    // Create Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Find users within 500m who have FCM tokens
    // Note: You'll need to store user locations and FCM tokens
    const { data: nearbyUsers, error } = await supabase
      .from("user_locations")
      .select("user_id, fcm_token")
      .neq("user_id", user_id) // Exclude the caller
      .not("fcm_token", "is", null)
      // Simple distance check (you can use PostGIS for more accuracy)
      .filter("lat", "gte", lat - 0.0045)  // roughly 500m
      .filter("lat", "lte", lat + 0.0045)
      .filter("lng", "gte", lng - 0.0045)
      .filter("lng", "lte", lng + 0.0045);

    if (error) throw error;

    console.log(`Found ${nearbyUsers?.length || 0} nearby users`);

    // Send FCM to each user
    const results = [];
    for (const user of nearbyUsers || []) {
      try {
        const result = await sendFCM(
          user.fcm_token,
          "🚨 EMERGENCY NEARBY",
          `${type} emergency within 500m! Tap to respond.`,
          {
            emergency_id: emergency_id,
            type: type,
            lat: String(lat),
            lng: String(lng),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          }
        );
        results.push({ user: user.user_id, success: true, result });
      } catch (e) {
        results.push({ user: user.user_id, success: false, error: e.message });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        sent: results.filter(r => r.success).length,
        failed: results.filter(r => !r.success).length,
        details: results,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error) {
    console.error('Error in emergency-push:', error);
    return new Response(
      JSON.stringify({ error: error.message, success: false }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});