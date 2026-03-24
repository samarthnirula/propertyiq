// pages/area_report_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class AreaReportPage extends StatefulWidget {
  final String areaInput;
  const AreaReportPage({super.key, required this.areaInput});

  @override
  State<AreaReportPage> createState() => _AreaReportPageState();
}

class _AreaReportPageState extends State<AreaReportPage> {
  Map<String, dynamic>? report;
  bool loading = true;
  bool deepLoading = false;
  String? error;
  bool isDeep = false;

  final TextEditingController _qaController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _qaHistory = [];
  bool _qaLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    _qaController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    try {
      final r = await ApiService.fetchAreaReport(widget.areaInput);
      setState(() { report = r; loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _loadDeepReport() async {
    setState(() => deepLoading = true);
    try {
      final r = await ApiService.fetchDeepAreaReport(widget.areaInput);
      setState(() { report = r; deepLoading = false; isDeep = true; });
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } catch (e) {
      setState(() => deepLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deep research failed: $e")));
      }
    }
  }

  Future<void> _askQuestion() async {
    final q = _qaController.text.trim();
    if (q.isEmpty || _qaLoading) return;
    setState(() {
      _qaLoading = true;
      _qaHistory.add({"role": "user", "text": q});
      _qaController.clear();
    });
    try {
      final answer = await ApiService.askAreaFollowup(widget.areaInput, q);
      setState(() => _qaHistory.add({"role": "agent", "text": answer}));
    } catch (e) {
      setState(() => _qaHistory.add({"role": "agent", "text": "Could not get answer: $e"}));
    } finally {
      setState(() => _qaLoading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildNarrative(String text, ThemeData theme) {
    final pattern = RegExp(r'\[([^\]]+)\]\((https?://[^\)]+)\)');
    final spans = <InlineSpan>[];
    int last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) spans.add(TextSpan(text: text.substring(last, match.start)));
      final name = match.group(1)!;
      final url = match.group(2)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _launchUrl(url),
          child: Text(name, style: TextStyle(color: theme.primaryColor, decoration: TextDecoration.underline, fontSize: 14)),
        ),
      ));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return RichText(
      text: TextSpan(
        style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 14, height: 1.7),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary = theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.areaInput, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: loading
          ? _buildLoading(theme, textPrimary, textSecondary)
          : error != null
              ? _buildError(theme, textPrimary, textSecondary)
              : _buildReport(theme, textPrimary, textSecondary),
    );
  }

  Widget _buildLoading(ThemeData theme, Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, color: theme.primaryColor)),
          const SizedBox(height: 24),
          Text("Researching ${widget.areaInput}", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary)),
          const SizedBox(height: 8),
          Text("Searching reputable sources & connecting the dots", style: TextStyle(color: textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme, Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text("Research failed", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () { setState(() { loading = true; error = null; }); _loadReport(); },
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(ThemeData theme, Color textPrimary, Color textSecondary) {
    final r = report!;
    final sections = (r["sections"] as List<dynamic>? ?? []);
    final keyInsights = (r["key_insights"] as List<dynamic>? ?? []);
    final sources = (r["sources"] as List<dynamic>? ?? []);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDeep)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.auto_awesome, color: Colors.white, size: 13), SizedBox(width: 6), Text("Deep Research", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))],
              ),
            ),
          Text(r["title"] ?? widget.areaInput, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary, height: 1.2)),
          const SizedBox(height: 6),
          Text("${sources.length} sources", style: TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.primaryColor.withOpacity(0.15))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.summarize_rounded, size: 15, color: theme.primaryColor), const SizedBox(width: 7), Text("Summary", style: TextStyle(fontWeight: FontWeight.w700, color: theme.primaryColor, fontSize: 13))]),
                const SizedBox(height: 10),
                _buildNarrative(r["executive_summary"] ?? "", theme),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!isDeep)
            deepLoading
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    onTap: _loadDeepReport,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                          SizedBox(width: 10),
                          Text("Deep Dive this Neighborhood", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
          const SizedBox(height: 24),
          if (keyInsights.isNotEmpty) ...[
            Text("Key Insights", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
            const SizedBox(height: 12),
            ...keyInsights.asMap().entries.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: theme.cardTheme.color,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 11, backgroundColor: theme.primaryColor, child: Text("${e.key + 1}", style: const TextStyle(color: Colors.white, fontSize: 11))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildNarrative(e.value.toString(), theme)),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 24),
          ],
          Text("Full Research", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 12),
          ...sections.map((section) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: theme.cardTheme.color,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((section["heading"] ?? "").toString(), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary)),
                  const SizedBox(height: 12),
                  _buildNarrative((section["narrative"] ?? "").toString(), theme),
                ],
              ),
            ),
          )),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
