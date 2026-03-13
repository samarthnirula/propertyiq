// pages/area_report_page.dart
// Perplexity-style narrative report with Deep Dive button

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
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    } catch (e) {
      setState(() => deepLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deep research failed: $e")));
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

  Widget _buildNarrative(String text) {
    final pattern = RegExp(r'\[([^\]]+)\]\((https?://[^\)]+)\)');
    final spans = <InlineSpan>[];
    int last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      final name = match.group(1)!;
      final url = match.group(2)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _launchUrl(url),
          child: Text(name,
              style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  decoration: TextDecoration.underline,
                  fontSize: 14)),
        ),
      ));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF374151), fontSize: 14, height: 1.7),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F5);
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.areaInput,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: loading
          ? _buildLoading(textPrimary, textSecondary)
          : error != null
              ? _buildError(textPrimary, textSecondary)
              : _buildReport(cardBg, bg, border, textPrimary, textSecondary, isDark),
    );
  }

  Widget _buildLoading(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(height: 24),
          Text("Researching ${widget.areaInput}",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary)),
          const SizedBox(height: 8),
          Text("Searching reputable sources & connecting the dots",
              style: TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text("~60–90 seconds", style: TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildError(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text("Research failed", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            Text(error!, textAlign: TextAlign.center, style: TextStyle(color: textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () { setState(() { loading = true; error = null; }); _loadReport(); },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(Color cardBg, Color bg, Color border, Color textPrimary, Color textSecondary, bool isDark) {
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
          // Deep badge
          if (isDeep)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                  SizedBox(width: 6),
                  Text("Deep Research", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

          // Title
          Text(r["title"] ?? widget.areaInput,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary, height: 1.2, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(
            "${sources.length} sources · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Executive Summary
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.summarize_rounded, size: 15, color: Color(0xFF3B82F6)),
                  SizedBox(width: 7),
                  Text("Summary", style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3B82F6), fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                _buildNarrative(r["executive_summary"] ?? ""),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Deep Dive button (only show if not already deep)
          if (!isDeep)
            deepLoading
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text("Running deep research (~3 min)...",
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _loadDeepReport,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Deep Dive this Neighborhood",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                              Text("12 targeted searches · more data · deeper analysis",
                                  style: TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white54, size: 16),
                        ],
                      ),
                    ),
                  ),

          const SizedBox(height: 24),

          // Key Insights
          if (keyInsights.isNotEmpty) ...[
            Text("Key Insights", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3)),
            const SizedBox(height: 12),
            ...keyInsights.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                    child: Center(child: Text("${e.key + 1}",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildNarrative(e.value.toString())),
                ],
              ),
            )),
            const SizedBox(height: 24),
          ],

          // Research Sections
          Text("Full Research", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          ...sections.map((section) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((section["heading"] ?? "").toString(),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary)),
                const SizedBox(height: 12),
                _buildNarrative((section["narrative"] ?? "").toString()),
              ],
            ),
          )),
          const SizedBox(height: 8),

          // Opportunities + Risks side by side hint
          if (r["opportunities"] != null || r["risks"] != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r["opportunities"] != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF059669).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.trending_up_rounded, color: Color(0xFF059669), size: 15),
                            SizedBox(width: 6),
                            Text("Opportunities", style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 13)),
                          ]),
                          const SizedBox(height: 10),
                          _buildNarrative(r["opportunities"].toString()),
                        ],
                      ),
                    ),
                  ),
                if (r["opportunities"] != null && r["risks"] != null) const SizedBox(width: 10),
                if (r["risks"] != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 15),
                            SizedBox(width: 6),
                            Text("Risks", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 13)),
                          ]),
                          const SizedBox(height: 10),
                          _buildNarrative(r["risks"].toString()),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Bottom Line
          if (r["bottom_line"] != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Bottom Line",
                      style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(r["bottom_line"].toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, height: 1.6)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Sources
          if (sources.isNotEmpty) ...[
            Text("${sources.length} Sources", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Column(
                children: sources.asMap().entries.map((e) {
                  final s = e.value;
                  final isLast = e.key == sources.length - 1;
                  return InkWell(
                    onTap: () => _launchUrl((s["url"] ?? "").toString()),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: isLast ? null : Border(bottom: BorderSide(color: border)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 15, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              (s["name"] ?? s["url"] ?? "").toString(),
                              style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Q&A
          Text("Ask a Follow-up",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text("Based on the research above",
              style: TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          ..._qaHistory.map((item) {
            final isUser = item["role"] == "user";
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF1A1A1A) : cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: isUser ? null : Border.all(color: border),
                ),
                child: isUser
                    ? Text(item["text"] ?? "", style: const TextStyle(color: Colors.white, fontSize: 14))
                    : _buildNarrative(item["text"] ?? ""),
              ),
            );
          }),
          if (_qaLoading)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text("Analyzing...", style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _qaController,
                    onSubmitted: (_) => _askQuestion(),
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "e.g. How bad is flooding in this area?",
                      hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _qaLoading ? null : _askQuestion,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _qaLoading ? Colors.grey.shade300 : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
