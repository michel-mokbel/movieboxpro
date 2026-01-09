// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:ui';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/main.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';
import 'package:moviemagicbox/widgets/bento_card.dart';
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
    const String appUrl = 'https://apps.apple.com/us/app/movie-box-pro/id6757599133';
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
                    child: const Text('Done', style: TextStyle(color: BentoTheme.accent)),
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
          child: const Text('Cancel', style: TextStyle(color: BentoTheme.accent)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: Stack(
        children: [
          _buildBackground(),
          FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Settings', style: BentoTheme.subtitle.copyWith(letterSpacing: 1.4)),
                        const SizedBox(height: 6),
                        Text('Your account & tools', style: BentoTheme.display),
                        const SizedBox(height: 24),
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        Text('PREFERENCES', style: BentoTheme.caption.copyWith(letterSpacing: 2)),
                        const SizedBox(height: 12),
                        _buildSettingsGroup([
                          _SettingsTileData(
                            icon: CupertinoIcons.bell_fill,
                            iconColor: BentoTheme.accent,
                            title: 'Movie Reminders',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RemindersScreen(),
                                ),
                              );
                            },
                          ),
                          _SettingsTileData(
                            icon: CupertinoIcons.ticket_fill,
                            iconColor: BentoTheme.accent,
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
                          _SettingsTileData(
                            icon: CupertinoIcons.globe,
                            iconColor: BentoTheme.accentSoft,
                            title: 'Language',
                            value: 'English',
                            onTap: () => showLanguageSelectionDialog(context),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        Text('SUPPORT', style: BentoTheme.caption.copyWith(letterSpacing: 2)),
                        const SizedBox(height: 12),
                        _buildSettingsGroup([
                          _SettingsTileData(
                            icon: CupertinoIcons.share,
                            iconColor: Colors.green,
                            title: 'Share App',
                            onTap: () => shareApp(context),
                          ),
                          _SettingsTileData(
                            icon: CupertinoIcons.hand_raised_fill,
                            iconColor: Colors.orange,
                            title: 'Privacy Policy',
                            onTap: () => showPrivacyPolicy(context),
                          ),
                        ]),
                        const SizedBox(height: 80),
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

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: BentoTheme.backgroundGradient,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildProfileCard() {
    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: BentoTheme.accent, width: 2),
            ),
            child: const CircleAvatar(
              radius: 28,
              backgroundImage: AssetImage('lib/assets/images/profile-pic.png'),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guest User', style: BentoTheme.title.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text('Movie Enthusiast', style: BentoTheme.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<_SettingsTileData> tiles) {
    return BentoCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final index = entry.key;
          final tile = entry.value;
          final isLast = index == tiles.length - 1;

          return Column(
            children: [
              _buildSettingsTile(tile),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 68,
                  endIndent: 24,
                  color: BentoTheme.outline,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsTile(_SettingsTileData tile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          tile.onTap();
        },
        borderRadius: BorderRadius.circular(BentoTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tile.iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tile.icon, color: tile.iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(tile.title, style: BentoTheme.body.copyWith(color: Colors.white)),
              ),
              if (tile.value != null) ...[
                Text(tile.value!, style: BentoTheme.body.copyWith(color: BentoTheme.textMuted)),
                const SizedBox(width: 8),
              ],
              const Icon(CupertinoIcons.chevron_right, color: BentoTheme.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTileData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? value;
  final VoidCallback onTap;

  _SettingsTileData({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.value,
    required this.onTap,
  });
}
