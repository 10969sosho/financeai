import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final Dio _dio;

  ImageService(this._dio);

  Future<File?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    return photo != null ? File(photo.path) : null;
  }

  Future<File?> pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    return image != null ? File(image.path) : null;
  }

  Future<Map<String, dynamic>?> uploadReceipt(File imageFile,
      {String? description}) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        if (description != null) 'description': description,
      });

      final response = await _dio.post(
        '/transactions/from-receipt',
        data: formData,
      );

      return response.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }
}
