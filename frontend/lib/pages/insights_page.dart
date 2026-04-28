// pages/insights_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'area_report_page.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, dynamic>> _personalInsights = [];
  List<Map<String, dynamic>> _housingNews = [];
  bool _loadingInsights = true;
  bool _loadingNews = true;
  static const String userId = "demo_user";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadInsights();
    _loadNews();
  }

  Future<void> _loadInsights() async {
    try {
      final data = await ApiService.fetchInsights(userId);
      setState(() { _personalInsights = data; _loadingInsights = false; });
    } catch (_) { setState(() => _loadingInsights = false); }
  }

  Future<void> _loadNews() async {
    try {
      final data = await ApiService.fetchHousingNews();
      setState(() { _housingNews = data; _loadingNews = false; });
    } catch (_) { setState(() => _loadingNews = false); }
  }

  void _search() {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    _searchFocus.unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (_) => AreaReportPage(areaInput: q)));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? Colors.grey;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Discover", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary)),
                    Text("Real estate intelligence, personalized", style: TextStyle(fontSize: 14, color: textSecondary)),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(Icons.search_rounded, color: textSecondary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              onSubmitted: (_) => _search(),
                              style: TextStyle(color: textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: "Search any area, zipcode, or neighborhood...",
                                hintStyle: TextStyle(color: textSecondary, fontSize: 15),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _search,
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Your Alerts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
                    GestureDetector(
                      onTap: () { setState(() => _loadingInsights = true); _loadInsights(); },
                      child: Text("Refresh", style: TextStyle(fontSize: 13, color: theme.primaryColor, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_loadingInsights)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())))
            else if (_personalInsights.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
                    child: Text("No alerts yet. Search properties and the agent will generate personalized market alerts.", style: TextStyle(color: textSecondary, fontSize: 14)),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text("US Housing Market", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)))),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_loadingNews)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _buildNewsCard(_housingNews[i], theme, textPrimary, textSecondary),
                  ),
                  childCount: _housingNews.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> news, ThemeData theme, Color textPrimary, Color textSecondary) {
    return GestureDetector(
      onTap: () {
        final url = (news["url"] ?? "") as String;
        if (url.isNotEmpty) _launchUrl(url);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(news["title"] ?? "", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(news["summary"] ?? "", style: TextStyle(color: textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.open_in_new_rounded, size: 16, color: theme.primaryColor),
          ],
        ),
      ),
    );
  }
}
