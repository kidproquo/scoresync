import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import '../models/measure_detection.dart';

class MeasureDetectionService {
  static const String apiUrl = 'https://dabba.princesamuel.me/symph/upload_and_predict';
  static const int maxFileSizeMB = 20;

  static Future<MeasureDetectionResult?> detectMeasures(File pdfFile, {http.Client? client}) async {
    // Use provided client or create a new one
    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    try {
      // Check file size
      final fileSizeInMB = await pdfFile.length() / (1024 * 1024);
      if (fileSizeInMB > maxFileSizeMB) {
        throw Exception('PDF file is too large (${fileSizeInMB.toStringAsFixed(1)}MB). Maximum size is ${maxFileSizeMB}MB.');
      }

      developer.log('Starting measure detection for file: ${pdfFile.path}');

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          pdfFile.path,
          filename: pdfFile.path.split('/').last,
        ),
      );

      // Send request without timeout using the client
      final streamedResponse = await httpClient.send(request);

      // Read response
      final response = await http.Response.fromStream(streamedResponse);

      developer.log('Measure detection response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = MeasureDetectionResult.fromJson(json);

        developer.log('Successfully detected measures: ${result.pages.fold(0, (sum, page) => sum + page.systemMeasures.length)} total measures across ${result.totalPages} pages');

        return result;
      } else {
        developer.log('Measure detection failed with status ${response.statusCode}: ${response.body}');
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error during measure detection: $e');
      rethrow;
    } finally {
      // Close the client if we created it
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }
}