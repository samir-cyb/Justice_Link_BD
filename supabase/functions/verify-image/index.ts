// supabase/functions/verify-image/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { reportId, imageUrl, verificationData, userId, crimeCategory } = await req.json()

    console.log('Server-side verification for report:', reportId)
    console.log('Image URL:', imageUrl)
    console.log('Crime category:', crimeCategory)

    // Step 1: Check if this is a sensitive crime category
    const sensitiveCategories = ['killing', 'murder', 'homicide', 'dead body', 'violent death']
    const isSensitive = sensitiveCategories.some(cat =>
      crimeCategory.toLowerCase().includes(cat.toLowerCase())
    )

    // Step 2: Store verification in database
    const verificationResult = {
      report_id: reportId,
      image_url: imageUrl,
      user_id: userId,
      client_check: verificationData,
      crime_category: crimeCategory,
      is_sensitive: isSensitive,
      needs_human_review: isSensitive,
      overall_status: isSensitive ? 'needs_review' : 'approved',
      created_at: new Date().toISOString(),
    }

    // Here you would:
    // 1. Save to Supabase database
    // 2. Run additional server-side checks
    // 3. Check against a larger fake image database
    // 4. Log for moderation

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Verification received',
        overall_status: isSensitive ? 'needs_review' : 'approved',
        is_sensitive: isSensitive,
        next_step: isSensitive ? 'human_moderation' : 'publish'
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )

  } catch (error) {
    console.error('Error in verify-image:', error)
    return new Response(
      JSON.stringify({
        error: error.message,
        success: false
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    )
  }
})