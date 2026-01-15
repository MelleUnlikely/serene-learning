import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../upload_service.dart';

class CreateFlashcardScreen extends StatefulWidget {
  final int lessonId; 
  const CreateFlashcardScreen({super.key, required this.lessonId});

  @override
  State<CreateFlashcardScreen> createState() => _CreateFlashcardScreenState();
}

class _CreateFlashcardScreenState extends State<CreateFlashcardScreen> {
  final _meaningController = TextEditingController();
  String? _uploadedImgUrl;
  String? _uploadedVideoUrl;
  bool _isUploading = false;
  
  List<Map<String, dynamic>> _existingCards = [];

  @override
  void initState() {
    super.initState();
    _fetchFlashcards();
  }

  // Fetch flashcards
  Future<void> _fetchFlashcards() async {
    final data = await Supabase.instance.client
        .from('flashcard')
        .select()
        .eq('lessonid', widget.lessonId)
        .order('created_at'); 
    
    setState(() => _existingCards = List<Map<String, dynamic>>.from(data));
  }

double _uploadProgress = 0;

  Future<void> handleUpload(String type) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });
    
    final String folder = type == 'image' ? 'images' : 'videos';
    final url = await pickAndUploadFile(folder, (progress) {
      setState(() => _uploadProgress = progress);
    });
    
    setState(() {
      if (type == 'image') {
        _uploadedImgUrl = url;
      } else {
        _uploadedVideoUrl = url;
      }
      _isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Manage Cards - Lesson #${widget.lessonId}")),
      body: Column(
        children: [
          // Input Fields
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(controller: _meaningController, decoration: const InputDecoration(labelText: "Sign Meaning")),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: Icon(Icons.image, color: _uploadedImgUrl != null ? Colors.green : null),
                      title: Text(_uploadedImgUrl == null ? "Upload Image" : "Image Ready"),
                      onTap: () => handleUpload('image'),
                    ),
                    ListTile(
                      leading: Icon(Icons.movie, color: _uploadedVideoUrl != null ? Colors.green : null),
                      title: Text(_uploadedVideoUrl == null ? "Upload Video" : "Video Ready"),
                      onTap: () => handleUpload('video'),
                    ),
                    const SizedBox(height: 10),
                    _isUploading 
                      ? const CircularProgressIndicator() 
                      : ElevatedButton(
                          onPressed: (_uploadedImgUrl != null && _uploadedVideoUrl != null) ? _saveFlashcard : null, 
                          child: const Text("Add Flashcard to Lesson"),
                        ),
                  ],
                ),  
              ),
            ),
          ),
          
          if (_isUploading) 
        Column(
          children: [
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 8),
            Text("${(_uploadProgress * 100).toInt()}% Uploading... Please wait."),
          ],
        ),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text("Current Cards in this Lesson", style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          // Existing cards
          Expanded(
            child: ListView.builder(
              itemCount: _existingCards.length,
              itemBuilder: (context, index) {
                final card = _existingCards[index];
                return ListTile(
                  leading: Image.network(card['imgurl'], width: 50, height: 50, fit: BoxFit.cover, 
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image)),
                  title: Text(card['signmeaning']),
                  subtitle: const Text("Video & Image attached"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCard(card['flashcardid']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFlashcard() async {
      if (_meaningController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a meaning for the sign")),
        );
        return;
      }

      try {

        await Supabase.instance.client.from('flashcard').insert({
          'lessonid': widget.lessonId,
          'signmeaning': _meaningController.text.trim(), 
          'videourl': _uploadedVideoUrl, 
          'imgurl': _uploadedImgUrl,     
        });

        // clear for the next card
        _meaningController.clear();
        setState(() {
          _uploadedImgUrl = null;
          _uploadedVideoUrl = null;
          _uploadProgress = 0;
        });
        
        _fetchFlashcards(); 
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Flashcard saved!"), backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Database Error: $e"), backgroundColor: Colors.red)
        );
      }
    }

    Future<void> _deleteCard(Map<String, dynamic> card) async {
    final id = card['flashcardid'];
    final String? imgUrl = card['imgurl'];
    final String? videoUrl = card['videourl'];

    try {
      // remove files from medi bucket
      List<String> filesToDelete = [];
      
      if (imgUrl != null) filesToDelete.add(_getFilePathFromUrl(imgUrl));
      if (videoUrl != null) filesToDelete.add(_getFilePathFromUrl(videoUrl));

      if (filesToDelete.isNotEmpty) {
        await Supabase.instance.client.storage
            .from('media')
            .remove(filesToDelete);
      }

      //Remove the row from the Database
      await Supabase.instance.client
          .from('flashcard')
          .delete()
          .eq('flashcardid', id);

      _fetchFlashcards();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Card and associated files deleted.")),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  String _getFilePathFromUrl(String url) {
    final Uri uri = Uri.parse(url);
    final List<String> pathSegments = uri.pathSegments;
    int mediaIndex = pathSegments.indexOf('media');
    return pathSegments.sublist(mediaIndex + 1).join('/');
  }

}