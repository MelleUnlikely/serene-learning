import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../upload_service.dart';
import 'package:flutter_application_1/widgets/serene_menu.dart';

class CreateFlashcardScreen extends StatefulWidget {
  final int lessonId;
  final String lessontitle;
  
  const CreateFlashcardScreen({super.key, required this.lessonId, required this.lessontitle});

  @override
  State<CreateFlashcardScreen> createState() => _CreateFlashcardScreenState();
}

class _CreateFlashcardScreenState extends State<CreateFlashcardScreen> {
  final _meaningController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldkey = GlobalKey<ScaffoldState>();

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
      backgroundColor: Colors.white,
      key: _scaffoldkey,
      endDrawer: const SereneDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackButton(color: Color(0xFF1D5A71)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Serene",
          style: TextStyle(
            color: Color(0xFF1D5A71),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Color(0xFF1D4E5F)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1D4E5F)),
            onPressed: () {
              _scaffoldkey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: 15),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Color(0xFF1D5A71),
            height: 1.0,
          )),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(
              "Manage Cards - ${widget.lessontitle}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D5A71),
              ),
            ),
          ),

          // Input Fields
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: Color(0xFFD0EDF9),
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(controller: _meaningController, decoration: const InputDecoration(labelText: "Sign Meaning",
                      labelStyle: TextStyle(color: Color(0xFF1D5A71)))),
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
                          child: const Text("Add Flashcard to Lesson",
                          style: TextStyle(color: Color(0xFF1D5A71)),),
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
          const Divider(thickness: 1, color: Color(0xFF1D5A71)),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text("Current Cards in this Lesson",
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D5A71))),
          ),

          // Existing cards
          Expanded(
            child: _existingCards.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.style_outlined, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      "No flashcards yet.",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const Text(
                      "Upload a sign above to get started!",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],//pag empty ung cards for the lesson
                ),
              )
              : ListView.builder(
                itemCount: _existingCards.length,
                itemBuilder: (context, index){
                  final card = _existingCards[index];
                  return ListTile(
                    leading: Image.network(
                      card['imgurl'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image),
                    ),
                    title: Text(card['signmeaning']),
                    subtitle: const Text("Video & Image attached"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCard(card),
                    ),
                  );
                },
              )
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
      List<String> filesToDelete = [];
      if (imgUrl != null && imgUrl.contains('media')) filesToDelete.add(_getFilePathFromUrl(imgUrl));
      if (videoUrl != null && videoUrl.contains('media')) filesToDelete.add(_getFilePathFromUrl(videoUrl));

      if (filesToDelete.isNotEmpty) {
        await Supabase.instance.client.storage
            .from('media')
            .remove(filesToDelete);
      }

      await Supabase.instance.client
          .from('flashcard')
          .delete()
          .eq('flashcardid', id);

      _fetchFlashcards();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Card and files deleted successfully!")),
        );
      }
    } catch (e) {
      debugPrint("Delete error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not delete: This card might be part of an existing Quiz."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
}

  String _getFilePathFromUrl(String url) {
    final Uri uri = Uri.parse(url);
    final List<String> pathSegments = uri.pathSegments;
    int mediaIndex = pathSegments.indexOf('media');
    return pathSegments.sublist(mediaIndex + 1).join('/');
  }

}