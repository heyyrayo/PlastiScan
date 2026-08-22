import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Storage Service
// ─────────────────────────────────────────────────────────────────────────────
//
// Responsible for:
// 1. Reading the selected image
// 2. Compressing the image
// 3. Uploading the image to Supabase Storage
//
// Storage structure:
//
// scan-images/
//     USER_ID/
//         scan_TIMESTAMP.jpg
//
// The user's Supabase ID is used as the first folder.
// This matches the Storage RLS policies created earlier.
// ─────────────────────────────────────────────────────────────────────────────

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  // Supabase client
  SupabaseClient get _supabase => Supabase.instance.client;

  // Storage bucket created in Supabase
  static const String bucketName = 'scan-images';

  // ───────────────────────────────────────────────────────────────────────────
  // Upload image
  // ───────────────────────────────────────────────────────────────────────────

  Future<StorageUploadResult> uploadScanImage({
    required String imagePath,
  }) async {
    // ─────────────────────────────────────────────────────────────────────────
    // Check authentication
    // ─────────────────────────────────────────────────────────────────────────

    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw const StorageUploadException(
        'You must be logged in before uploading a scan.',
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Read original image
    // ─────────────────────────────────────────────────────────────────────────

    final originalBytes = await XFile(imagePath).readAsBytes();

    if (originalBytes.isEmpty) {
      throw const StorageUploadException(
        'The selected image is empty.',
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Compress image
    // ─────────────────────────────────────────────────────────────────────────
    //
    // 1600 x 1600 gives enough detail for product labels while
    // keeping the upload reasonably small.
    //
    // JPEG quality 82 provides a good balance between:
    //
    // image quality
    //       +
    // upload speed
    //       +
    // storage usage
    //
    // ─────────────────────────────────────────────────────────────────────────

    final Uint8List compressedBytes =
        await FlutterImageCompress.compressWithList(
      originalBytes,
      minWidth: 1600,
      minHeight: 1600,
      quality: 82,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
      keepExif: false,
    );

    if (compressedBytes.isEmpty) {
      throw const StorageUploadException(
        'Image compression failed.',
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Generate unique filename
    // ─────────────────────────────────────────────────────────────────────────

    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final fileName = 'scan_$timestamp.jpg';

    // ─────────────────────────────────────────────────────────────────────────
    // User-specific folder
    // ─────────────────────────────────────────────────────────────────────────
    //
    // IMPORTANT:
    //
    // The Storage RLS policy expects:
    //
    // USER_ID/filename.jpg
    //
    // Example:
    //
    // 9a123.../scan_123456.jpg
    //
    // ─────────────────────────────────────────────────────────────────────────

    final storagePath = '${user.id}/$fileName';

    // ─────────────────────────────────────────────────────────────────────────
    // Upload
    // ─────────────────────────────────────────────────────────────────────────

    try {
      final uploadedPath =
          await _supabase.storage.from(bucketName).uploadBinary(
                storagePath,
                compressedBytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  cacheControl: '3600',
                  upsert: false,
                ),
              );

      // ───────────────────────────────────────────────────────────────────────
      // Return upload information
      // ───────────────────────────────────────────────────────────────────────

      return StorageUploadResult(
        path: uploadedPath,
        originalSizeBytes: originalBytes.length,
        compressedSizeBytes: compressedBytes.length,
      );
    } on StorageException catch (error) {
      throw StorageUploadException(
        error.message.isNotEmpty
            ? error.message
            : 'Could not upload the image.',
      );
    } catch (_) {
      throw const StorageUploadException(
        'Could not upload the image. Please check your internet connection.',
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload Result
// ─────────────────────────────────────────────────────────────────────────────

class StorageUploadResult {
  const StorageUploadResult({
    required this.path,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
  });

  final String path;

  final int originalSizeBytes;

  final int compressedSizeBytes;

  // Human-readable compression percentage.
  double get compressionPercentage {
    if (originalSizeBytes == 0) {
      return 0;
    }

    final saved = originalSizeBytes - compressedSizeBytes;

    return (saved / originalSizeBytes) * 100;
  }

  // Human-readable original size.
  double get originalSizeKb => originalSizeBytes / 1024;

  // Human-readable compressed size.
  double get compressedSizeKb => compressedSizeBytes / 1024;
}

// ─────────────────────────────────────────────────────────────────────────────
// Storage Upload Exception
// ─────────────────────────────────────────────────────────────────────────────

class StorageUploadException implements Exception {
  const StorageUploadException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}
