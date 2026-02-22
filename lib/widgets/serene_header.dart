import 'package:flutter/material.dart';

class SereneHeader extends StatelessWidget implements PreferredSizeWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool showBackButton;

  const SereneHeader({super.key, required this.scaffoldKey, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBackButton 
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
          Image.asset(
            'assets/images/logo.png',
            height: 32,
          ),
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
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Color(0xFF1D5A71)),
          onPressed: () {
            //logic ni notif
          },
        ),
        IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF1D5A71)),
          onPressed: () {
            scaffoldKey.currentState?.openEndDrawer();
          },
        ),
        const SizedBox(width: 15),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1.0),
        child: Divider(height: 1, color: Color(0xFF1D5A71)),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}