import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/analytics.dart';
import '../services/remote_settings.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';

/// News card at the top of Home, written in the Firebase console (Remote
/// Config `home_announcement_*`). Hidden while the title is empty. A learner
/// can dismiss it; a new `home_announcement_id` brings it back.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  static const _dismissedKey = 'dismissed_announcement_id';
  String? _dismissedId;
  String? _viewedId;

  @override
  void initState() {
    super.initState();
    RemoteSettings.changes.addListener(_refresh);
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _dismissedId = prefs.getString(_dismissedKey));
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    RemoteSettings.changes.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String get _id {
    final id = RemoteSettings.getString('home_announcement_id');
    return id.isNotEmpty ? id : RemoteSettings.getString('home_announcement_title');
  }

  Future<void> _dismiss() async {
    final id = _id;
    Analytics.track('announcement_dismissed', {'announcement': id});
    setState(() => _dismissedId = id);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, id);
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    Analytics.track('announcement_tapped', {'announcement': _id, 'url': url});
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final title = RemoteSettings.getString('home_announcement_title').trim();
    if (title.isEmpty || _id == _dismissedId) return const SizedBox.shrink();
    final body = RemoteSettings.getString('home_announcement_body').trim();
    final url = RemoteSettings.getString('home_announcement_url').trim();

    if (_viewedId != _id) {
      _viewedId = _id;
      Analytics.track('announcement_viewed', {'announcement': _id});
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Material(
        color: AppTokens.tint(AppColors.primary, context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: url.isEmpty ? null : () => _open(url),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.campaign_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTokens.ink(context),
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: AppTextStyles.poppins(
                            fontSize: 14,
                            color: AppTokens.inkSoft(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: Icon(Icons.close, color: AppTokens.inkSoft(context)),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
