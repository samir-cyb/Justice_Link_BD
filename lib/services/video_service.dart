import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';

class VideoService {
  // Supabase configuration
  static const String _videosBucket = 'crime-videos';
  static const String _imagesBucket = 'crime-images';

  // Size limits in MB
  static const double _limitDirect = 100;    // ≤100MB: Direct upload
  static const double _limit720p = 200;      // 100-200MB: 720p
  static const double _limit480p = 300;      // 200-300MB: 480p
  static const double _limit360p = 500;      // 300-500MB: 360p
  static const double _limitMax = 600;       // 500-600MB: 360p (LAST TIER)

  /// Upload image to Supabase Storage
  static Future<String?> uploadImage(File imageFile, String userId) async {
    try {
      if (!await imageFile.exists()) {
        developer.log('❌ Image file does not exist: ${imageFile.path}');
        return null;
      }

      final fileSize = await imageFile.length();
      final fileSizeMB = fileSize / (1024 * 1024);
      developer.log('📸 Uploading image: ${fileSizeMB.toStringAsFixed(2)} MB');

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = '$userId/$timestamp.jpg';
      final String mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';

      final supabase = Supabase.instance.client;

      // Upload to Supabase Storage
      await supabase.storage.from(_imagesBucket).upload(
        fileName,
        imageFile,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: false,
        ),
      );

      // Get public URL
      final String publicUrl = supabase.storage.from(_imagesBucket).getPublicUrl(fileName);

      developer.log('✅ Image uploaded successfully: $publicUrl');
      return publicUrl;

    } catch (e, stackTrace) {
      developer.log('❌ Image upload error: $e');
      developer.log('StackTrace: $stackTrace');
      return null;
    }
  }

  /// Upload multiple images to Supabase Storage
  static Future<List<String>> uploadImages(List<File> imageFiles, String userId) async {
    final List<String> urls = [];

    for (final imageFile in imageFiles) {
      final url = await uploadImage(imageFile, userId);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// Main entry point: Process video based on size tier and upload to Supabase
  static Future<String?> processAndUploadVideo(String videoPath, String userId) async {
    try {
      final file = File(videoPath);

      if (!await file.exists()) {
        developer.log('❌ Video file does not exist: $videoPath');
        return null;
      }

      final fileSize = await file.length();
      final fileSizeMB = fileSize / (1024 * 1024);

      developer.log('📹 Original video size: ${fileSizeMB.toStringAsFixed(2)} MB');

      // REJECTION: Above 600MB
      if (fileSizeMB > _limitMax) {
        developer.log('❌ Video too large: ${fileSizeMB.toStringAsFixed(2)}MB. Max allowed: $_limitMax MB');
        throw Exception('Video size exceeds maximum limit of $_limitMax MB. Please use a smaller video.');
      }

      File? processedFile;

      // TIER 1: Direct upload (≤100MB)
      if (fileSizeMB <= _limitDirect) {
        developer.log('✅ Tier 1: Direct upload (≤$_limitDirect MB)');
        processedFile = file;
      }
      // TIER 2: Compress to 720p (100-200MB)
      else if (fileSizeMB <= _limit720p) {
        developer.log('🗜️ Tier 2: Compressing to 720p ($_limitDirect-$_limit720p MB)');
        processedFile = await _compressTo720p(videoPath);
      }
      // TIER 3: Compress to 480p (200-300MB)
      else if (fileSizeMB <= _limit480p) {
        developer.log('🗜️ Tier 3: Compressing to 480p ($_limit720p-$_limit480p MB)');
        processedFile = await _compressTo480p(videoPath);
      }
      // TIER 4 & 5: Compress to 360p (300-600MB)
      else {
        developer.log('🗜️ Tier 4/5: Compressing to 360p (>${_limit480p} MB)');
        processedFile = await _compressTo360p(videoPath);
      }

      if (processedFile == null) {
        throw Exception('Video compression failed');
      }

      // Upload processed video to Supabase
      final String? url = await uploadVideo(processedFile, userId);

      // Clean up temp file if it was compressed
      if (processedFile.path != videoPath) {
        try {
          await processedFile.delete();
          developer.log('🧹 Cleaned up temp compressed file');
        } catch (e) {
          developer.log('⚠️ Failed to delete temp file: $e');
        }
      }

      return url;

    } catch (e, stackTrace) {
      developer.log('❌ Video processing error: $e');
      developer.log('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Upload video to Supabase Storage
  static Future<String?> uploadVideo(File videoFile, String userId) async {
    try {
      if (!await videoFile.exists()) {
        developer.log('❌ Upload failed: File does not exist');
        return null;
      }

      final fileSize = await videoFile.length();
      final fileSizeMB = fileSize / (1024 * 1024);
      developer.log('📤 Preparing upload: ${fileSizeMB.toStringAsFixed(2)} MB');

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = '$userId/$timestamp.mp4';
      final String mimeType = lookupMimeType(videoFile.path) ?? 'video/mp4';

      final supabase = Supabase.instance.client;

      developer.log('🚀 Uploading to Supabase Storage: $_videosBucket/$fileName');

      // Upload to Supabase Storage with timeout
      await supabase.storage.from(_videosBucket).upload(
        fileName,
        videoFile,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: false,
        ),
      ).timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          throw Exception('Upload timeout after 10 minutes');
        },
      );

      // Get public URL
      final String publicUrl = supabase.storage.from(_videosBucket).getPublicUrl(fileName);

      developer.log('✅ Upload successful!');
      developer.log('   🔗 Public URL: $publicUrl');
      developer.log('   📦 Size: ${fileSizeMB.toStringAsFixed(2)} MB');

      return publicUrl;

    } catch (e, stackTrace) {
      developer.log('❌ Upload exception: $e');
      developer.log('StackTrace: $stackTrace');
      return null;
    }
  }

  /// TIER 2: 720p compression (100-200 MB)
  static Future<File?> _compressTo720p(String videoPath) async {
    return await _runCompression(
        videoPath: videoPath,
        resolution: '1280x720',
        scaleFilter: 'scale=-2:720',
        crf: '28',
        preset: 'fast',
        tierName: '720p'
    );
  }

  /// TIER 3: 480p compression (200-300 MB)
  static Future<File?> _compressTo480p(String videoPath) async {
    return await _runCompression(
        videoPath: videoPath,
        resolution: '854x480',
        scaleFilter: 'scale=-2:480',
        crf: '30',
        preset: 'fast',
        tierName: '480p'
    );
  }

  /// TIER 4: 360p compression (300-600 MB) - FINAL TIER
  static Future<File?> _compressTo360p(String videoPath) async {
    return await _runCompression(
        videoPath: videoPath,
        resolution: '640x360',
        scaleFilter: 'scale=-2:360',
        crf: '32',
        preset: 'faster',
        tierName: '360p'
    );
  }

  /// Generic compression runner
  static Future<File?> _runCompression({
    required String videoPath,
    required String resolution,
    required String scaleFilter,
    required String crf,
    required String preset,
    required String tierName,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
          tempDir.path,
          'compressed_${tierName}_${DateTime.now().millisecondsSinceEpoch}.mp4'
      );

      // Build FFmpeg command
      final command =
          '-i "$videoPath" '
          '-c:v libx264 '
          '-crf $crf '
          '-preset $preset '
          '-vf "$scaleFilter,fps=30" '
          '-c:a aac '
          '-b:a 128k '
          '-movflags +faststart '
          '-max_muxing_queue_size 1024 '
          '"$outputPath"';

      developer.log('🔧 FFmpeg Command ($tierName): $command');

      final stopwatch = Stopwatch()..start();
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      stopwatch.stop();

      if (ReturnCode.isSuccess(returnCode)) {
        final compressedFile = File(outputPath);

        if (!await compressedFile.exists()) {
          developer.log('❌ Compression output file not found');
          return null;
        }

        final compressedSize = await compressedFile.length();
        final compressedSizeMB = compressedSize / (1024 * 1024);
        final originalSize = await File(videoPath).length();
        final compressionRatio = (originalSize / compressedSize).toStringAsFixed(2);

        developer.log('✅ $tierName compression complete:');
        developer.log('   📦 Output size: ${compressedSizeMB.toStringAsFixed(2)} MB');
        developer.log('   📉 Compression ratio: ${compressionRatio}x');
        developer.log('   ⏱️  Duration: ${stopwatch.elapsed.inSeconds}s');

        return compressedFile;

      } else {
        final output = await session.getOutput() ?? 'No output';
        final logs = await session.getLogs() ?? [];
        final failStackTrace = await session.getFailStackTrace();

        developer.log('❌ FFmpeg $tierName compression failed');
        developer.log('   Return Code: $returnCode');
        developer.log('   Output: $output');
        developer.log('   Logs: ${logs.map((l) => l.getMessage()).join('\n')}');
        if (failStackTrace != null) {
          developer.log('   StackTrace: $failStackTrace');
        }

        return null;
      }

    } catch (e, stackTrace) {
      developer.log('❌ Compression exception ($tierName): $e');
      developer.log('StackTrace: $stackTrace');
      return null;
    }
  }

  /// Get thumbnail URL from video (generates on-the-fly using Supabase transformations)
  /// Note: Supabase doesn't have built-in video thumbnails like Cloudinary
  /// This returns the video URL itself, or you can implement a frame extraction
  static String? getThumbnailUrl(String videoUrl) {
    // For Supabase, we can't easily generate thumbnails on-the-fly
    // You have two options:
    // 1. Extract a frame during upload and save it as a separate image
    // 2. Use a placeholder or the video URL itself

    // Returning null indicates no thumbnail available
    // The UI should handle this by showing a video icon placeholder
    developer.log('ℹ️ Thumbnail not available for Supabase video: $videoUrl');
    return null;
  }

  /// Extract thumbnail from video file (to be called during upload process)
  static Future<File?> extractThumbnail(String videoPath, {int timeInSeconds = 1}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
          tempDir.path,
          'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );

      final command =
          '-i "$videoPath" '
          '-ss 00:00:0$timeInSeconds '
          '-vframes 1 '
          '-q:v 2 '
          '"$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final thumbFile = File(outputPath);
        if (await thumbFile.exists()) {
          developer.log('✅ Thumbnail extracted: $outputPath');
          return thumbFile;
        }
      }

      developer.log('❌ Failed to extract thumbnail');
      return null;

    } catch (e) {
      developer.log('❌ Thumbnail extraction error: $e');
      return null;
    }
  }

  /// Upload thumbnail to Supabase and return URL
  static Future<String?> uploadThumbnail(File thumbFile, String userId) async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'thumbnails/$userId/$timestamp.jpg';

      final supabase = Supabase.instance.client;

      await supabase.storage.from(_videosBucket).upload(
        fileName,
        thumbFile,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final String publicUrl = supabase.storage.from(_videosBucket).getPublicUrl(fileName);

      // Clean up temp file
      try {
        await thumbFile.delete();
      } catch (e) {
        developer.log('⚠️ Failed to delete temp thumbnail: $e');
      }

      return publicUrl;

    } catch (e) {
      developer.log('❌ Thumbnail upload error: $e');
      return null;
    }
  }

  /// Clean up temporary compressed files
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = await tempDir
          .list()
          .where((entity) =>
      entity is File &&
          (path.basename(entity.path).startsWith('compressed_') ||
              path.basename(entity.path).startsWith('thumb_')))
          .toList();

      int deletedCount = 0;
      for (var file in files) {
        try {
          await file.delete();
          deletedCount++;
          developer.log('🗑️ Cleaned up: ${path.basename(file.path)}');
        } catch (e) {
          developer.log('⚠️ Failed to delete ${path.basename(file.path)}: $e');
        }
      }

      developer.log('✅ Cleanup complete: $deletedCount/${files.length} files removed');

    } catch (e, stackTrace) {
      developer.log('⚠️ Cleanup error: $e');
      developer.log('StackTrace: $stackTrace');
    }
  }

  /// Get video duration using FFprobe
  static Future<double?> getVideoDuration(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        developer.log('❌ Cannot get duration: File does not exist');
        return null;
      }

      final command = '-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$videoPath"';
      final session = await FFmpegKit.execute(command);
      final output = await session.getOutput();
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode) && output != null) {
        final duration = double.tryParse(output.trim());
        developer.log('⏱️  Video duration: ${duration?.toStringAsFixed(2)}s');
        return duration;
      }

      return null;
    } catch (e) {
      developer.log('❌ Error getting video duration: $e');
      return null;
    }
  }

  /// Delete video from Supabase Storage
  static Future<bool> deleteVideo(String videoUrl) async {
    try {
      final supabase = Supabase.instance.client;

      // Extract path from URL
      final uri = Uri.parse(videoUrl);
      final pathSegments = uri.pathSegments;

      // Find the bucket name index
      final bucketIndex = pathSegments.indexOf(_videosBucket);
      if (bucketIndex == -1 || bucketIndex + 1 >= pathSegments.length) {
        developer.log('❌ Could not extract path from URL: $videoUrl');
        return false;
      }

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      await supabase.storage.from(_videosBucket).remove([filePath]);
      developer.log('✅ Video deleted: $filePath');
      return true;

    } catch (e) {
      developer.log('❌ Failed to delete video: $e');
      return false;
    }
  }

  /// Dispose any resources
  static void dispose() {
    developer.log('🧹 VideoService disposed');
  }
}