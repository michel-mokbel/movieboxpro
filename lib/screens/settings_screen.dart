// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:ui';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/main.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'cinemas_screen.dart';
import 'reminders_screen.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void shareApp(BuildContext context) {
    const String appUrl = 'https://apps.apple.com/us/app/movie-box-pro/id6756583616';
    Share.share(appUrl);
  }

  void showPrivacyPolicy(BuildContext context) async {
    HapticFeedback.selectionClick();
    String htmlFilePath = 'lib/assets/html/privacy_policy_en.html';
    String htmlData = await rootBundle.loadString(htmlFilePath);

    if (!context.mounted) return;
    
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.white)
      ..loadRequest(
        Uri.dataFromString(
          htmlData,
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        ),
      );
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Privacy Policy', style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  )),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    child: const Text('Done', style: TextStyle(color: IOSTheme.systemBlue)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: WebViewWidget(controller: controller),
            ),
          ],
        ),
      ),
    );
  }

  // Show language selection dialog
  void showLanguageSelectionDialog(BuildContext context) {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Language'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              MyApp.setLocale(context, const Locale('en', ''));
          Navigator.pop(context);
        },
            child: const Text('English'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text('Cancel', style: TextStyle(color: IOSTheme.systemBlue)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
            children: [
          // Ambient Background
              Container(
            decoration: const BoxDecoration(
                  gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A0A),
                  Colors.black,
                  Color(0xFF0A0A0A),
                ],
                  ),
            ),
          ),

          FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        Text(
                          "Settings",
                          style: IOSTheme.largeTitle.copyWith(
                            fontSize: 42,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: -1,
                      ),
                    ),
                        const SizedBox(height: 32),
                        
                        // Profile Section (Glass)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: IOSTheme.systemBlue, width: 2),
                          ),
                          child: const CircleAvatar(
                                  radius: 30,
                            backgroundImage: AssetImage('lib/assets/images/profile-pic.png'),
                          ),
                        ),
                              const SizedBox(width: 20),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Guest User', style: IOSTheme.title2),
                                  const SizedBox(height: 4),
                                  Text('Movie Enthusiast', style: IOSTheme.subhead),
                      ],
                    ),
                  ],
                ),
              ),
                        
                        const SizedBox(height: 32),
                        Text("PREFERENCES", style: IOSTheme.caption1.copyWith(letterSpacing: 2)),
                        const SizedBox(height: 12),
                        
                        // Settings Group
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                                icon: CupertinoIcons.bell_fill,
                                iconColor: IOSTheme.systemBlue,
                        title: 'Movie Reminders',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RemindersScreen(),
                            ),
                          );
                        },
                                isFirst: true,
                      ),
                              _buildDivider(),
                      _buildSettingsTile(
                                icon: CupertinoIcons.ticket_fill,
                                iconColor: IOSTheme.systemBlue,
                        title: 'Cinemas',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CinemasScreen(),
                            ),
                          );
                        },
                      ),
                              _buildDivider(),
                      _buildSettingsTile(
                                icon: CupertinoIcons.globe,
                                iconColor: Colors.blue,
                        title: 'Language',
                                value: 'English',
                        onTap: () => showLanguageSelectionDialog(context),
                                isLast: true,
                      ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        Text("SUPPORT", style: IOSTheme.caption1.copyWith(letterSpacing: 2)),
                        const SizedBox(height: 12),
                        
                        // Support Group
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                      _buildSettingsTile(
                                icon: CupertinoIcons.share,
                                iconColor: Colors.green,
                        title: 'Share App',
                        onTap: () => shareApp(context),
                                isFirst: true,
                      ),
                              _buildDivider(),
                      _buildSettingsTile(
                                icon: CupertinoIcons.hand_raised_fill,
                                iconColor: Colors.orange,
                        title: 'Privacy Policy',
                        onTap: () => showPrivacyPolicy(context),
                                isLast: true,
                              ),
                            ],
                          ),
                      ),
                        
                        const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 24,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? value,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                  color: iconColor,
                  size: 20,
                  ),
                ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: IOSTheme.body.copyWith(fontWeight: FontWeight.w500),
                  ),
              ),
              if (value != null) ...[
                Text(
                  value,
                  style: IOSTheme.body.copyWith(color: IOSTheme.secondaryLabel),
                ),
                const SizedBox(width: 8),
              ],
                const Icon(
                CupertinoIcons.chevron_right,
                color: IOSTheme.tertiaryLabel,
                size: 18,
                ),
              ],
          ),
        ),
      ),
    );
  }
}
