import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> pickAndUploadFile(String folder, Function(double) onProgress) async {
  bool isImage = folder.contains('images');
  
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: isImage ? FileType.image : FileType.video,
    withData: true, 
  );

  if (result != null && result.files.first.bytes != null) {
    Uint8List fileBytes = result.files.first.bytes!;
    String fileName = result.files.first.name;
    final String path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    try {
      final String extension = fileName.split('.').last.toLowerCase();
      String mimeType;
      
      if (isImage) {
        if (extension == 'png') {
          mimeType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          mimeType = 'image/jpeg';
        } else {
          mimeType = 'image/$extension'; 
        }
      } else {
        mimeType = 'video/mp4';
      }

      onProgress(0.1); 

      await Supabase.instance.client.storage
          .from('media')
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeType, 
            ),
          );

      onProgress(1.0); 

      return Supabase.instance.client.storage
          .from('media')
          .getPublicUrl(path);

    } catch (e) {
      print('Upload error details: $e');
      return null;
    }
  }
  return null;
}