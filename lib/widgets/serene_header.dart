import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SereneHeader extends StatefulWidget implements PreferredSizeWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool showBackButton;

  const SereneHeader({
    super.key,
    required this.scaffoldKey,
    this.showBackButton = false,
  });

  @override
  State<SereneHeader> createState() => _SereneHeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

class _SereneHeaderState extends State<SereneHeader> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isNotificationOpen = false;
  String? userRole;

  List<Map<String, dynamic>> _notificationList = [];
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();

  }

  void _setupRealtimeSubscription() async {
  final authId = Supabase.instance.client.auth.currentUser?.id;
  if (authId == null) return;

  try {
    //Fetch the Integer ID (userid) from the profile
    final profileData = await Supabase.instance.client
        .from('profiles')
        .select('userid, roletype')
        .eq('uid', authId)
        .single();
    
    print("Fetched Profile Data: $profileData");

    final int teacherIntId = profileData['userid'];
    final String role = profileData['roletype'];

    if (mounted){
      setState(() {
        userRole = role;
      });
    }

    //Subscribe using the Integer ID
    _notificationChannel = Supabase.instance.client
        .channel('public:notification')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notification',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'teacher_id',
            value: teacherIntId, 
          ),
          callback: (payload) {
          if (mounted) {
            setState(() {
              _notificationList.insert(0, payload.newRecord);
            });
          }
        },
        )
        .subscribe();
        
    //Initial fetch of existing notifications
    final existingNotifs = await Supabase.instance.client
        .from('notification')
        .select()
        .eq('teacher_id', teacherIntId)
        .order('created_at', ascending: false)
        .limit(10);
        
    if (mounted) {
      setState(() {
        _notificationList = List<Map<String, dynamic>>.from(existingNotifs);
      });
    }
  } catch (e) {
    debugPrint("Error setting up notifications: $e");
  }
}


Future<void> _markAllAsRead() async {
  if (_notificationList.isEmpty) return;

  try {
    final unreadIds = _notificationList
        .where((n) => n['is_read'] == false)
        .map((n) => n['id'])
        .toList();

    if (unreadIds.isEmpty) return;

    await Supabase.instance.client
        .from('notification')
        .update({'is_read': true})
        .inFilter('id', unreadIds); 

    if (mounted) {
      setState(() {
        for (var notif in _notificationList) {
          notif['is_read'] = true;
        }
      });
    }
  } catch (e) {
    debugPrint("Error marking notifications as read: $e");
  }
}

  @override
  void dispose() {
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
    }
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleNotifications() {
  if (_isNotificationOpen) {
    _closeNotifications();
  } else {
    _showNotifications();
    _markAllAsRead();
  }
}

  void _showNotifications() {
    final overlay = Overlay.of(context);
    _overlayEntry = _createOverlayEntry();
    overlay.insert(_overlayEntry!);
    setState(() => _isNotificationOpen = true);
  }

  void _closeNotifications() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isNotificationOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _closeNotifications,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            width: 320,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-270, 45), 
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(15),
                color: Colors.white,
                child: _buildNotificationContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  

  Widget _buildNotificationContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFD0EDF9), 
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Student Activity",
                style: TextStyle(color: Color(0xFF1D5A71), fontWeight: FontWeight.bold),
              ),
              Icon(Icons.notifications_active, size: 18, color: Color(0xFF1D5A71)),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 350),
          child: _notificationList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No new quiz attempts.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _notificationList.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notif = _notificationList[index];
                    return ListTile(

                      tileColor: notif['is_read'] == false ? const Color(0xFFF0F9FF) : Colors.white,
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFFD0EDF9),
                        child: Icon(Icons.assignment_ind_rounded, color: Color(0xFF1D5A71), size: 20),
                      ),
                      title: Text(
                        notif['message'] ?? "Student attempted a quiz",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1D5A71)),
                      ),
                      subtitle: Text(
                        _formatTimestamp(notif['created_at']),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTimestamp(String? isoString) {
    if (isoString == null) return "";
    final date = DateTime.parse(isoString).toLocal();
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: widget.showBackButton
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1D5A71)),
            onPressed: () => Navigator.of(context).pop(),
          )
        : null,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', height: 32),
          const SizedBox(width: 10),
          const Text(
            "Serene",
            style: TextStyle(
              color: Color(0xFF1D5A71),
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
      actions: [
        if (userRole == 'Teacher')
          Stack(
            alignment: Alignment.center,
            children: [
              CompositedTransformTarget(
                link: _layerLink,
                child: IconButton(
                  icon: Icon(
                    _isNotificationOpen ? Icons.notifications : Icons.notifications_none,
                    color: const Color(0xFF1D5A71),
                  ),
                  onPressed: _toggleNotifications,
                ),
              ),
              if (_notificationList.any((n) => n['is_read'] == false)) 
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF1D5A71)),
          onPressed: () => widget.scaffoldKey.currentState?.openEndDrawer(),
        ),
        const SizedBox(width: 15),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1.0),
        child: Divider(height: 1, color: Color(0xFF1D5A71)),
      ),
    );
  }
}