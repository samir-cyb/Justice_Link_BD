import 'package:supabase_flutter/supabase_flutter.dart';

class CostAnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getMonthlySavings() async {
    try {
      final response = await _supabase
          .from('image_verifications')
          .select('*')
          .gte('created_at', DateTime.now().subtract(Duration(days: 30)).toIso8601String());

      final verifications = List<Map<String, dynamic>>.from(response);

      int totalImages = verifications.length;
      int rejectedByMetadata = verifications.where((v) =>
      v['metadata_check']?['passed'] == false).length;
      int rejectedByHash = verifications.where((v) =>
      v['hash_check']?['passed'] == false).length;
      int rejectedByML = verifications.where((v) =>
      v['ml_kit_check']?['passed'] == false).length;
      int sentToGoogleVision = verifications.where((v) =>
      v['google_vision_check'] != null).length;

      double originalCost = totalImages * 0.0015; // $1.50 per 1000
      double actualCost = sentToGoogleVision * 0.0015; // $1.50 per 1000
      double savings = originalCost - actualCost;
      double savingsPercentage = ((savings / originalCost) * 100);

      return {
        'total_images': totalImages,
        'rejected_by_metadata': rejectedByMetadata,
        'rejected_by_hash': rejectedByHash,
        'rejected_by_ml': rejectedByML,
        'sent_to_google_vision': sentToGoogleVision,
        'original_cost': originalCost,
        'actual_cost': actualCost,
        'savings': savings,
        'savings_percentage': savingsPercentage,
        'efficiency': '${(100 - (sentToGoogleVision/totalImages*100)).toStringAsFixed(1)}%',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}