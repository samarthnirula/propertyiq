import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../models/address_suggesstion.dart';
import '../models/listing.dart';
import '../models/area_stats.dart';
import '../widgets/area_stats_panel.dart';
import 'area_report_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _statsKey = GlobalKey();
  final TextEditingController searchController = TextEditingController();
  final MapController _mapController = MapController();
  Timer? debounce;

  List<AddressSuggestion> suggestions = [];
  AddressSuggestion? selected;

  List<Listing> listings = [];
  bool loadingListings = false;
  bool _showStats = false;

  String status = "Search for a property address or ZIP";
  String? listingsError;

  AreaStats? areaStats;
  bool loadingStats = false;
  String? statsError;

  String? _activeMapZip;

  final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

  final List<Map<String, String>> _topZipCodes = const [
    {'zip': '76258', 'error': '0.06%'},
    {'zip': '76036', 'error': '0.16%'},
    {'zip': '75056', 'error': '0.33%'},
    {'zip': '75409', 'error': '0.28%'},
    {'zip': '75156', 'error': '0.27%'},
  ];

  static const List<_ZipMarkerData> _zipLocations = [
    _ZipMarkerData(zip: '75001', lat: 32.9618, lng: -96.8373),
    _ZipMarkerData(zip: '75002', lat: 33.0890, lng: -96.6060),
    _ZipMarkerData(zip: '75006', lat: 32.9610, lng: -96.8970),
    _ZipMarkerData(zip: '75007', lat: 33.0040, lng: -96.8970),
    _ZipMarkerData(zip: '75009', lat: 33.3380, lng: -96.7420),
    _ZipMarkerData(zip: '75010', lat: 33.0310, lng: -96.9150),
    _ZipMarkerData(zip: '75013', lat: 33.1270, lng: -96.6980),
    _ZipMarkerData(zip: '75019', lat: 32.9560, lng: -96.9850),
    _ZipMarkerData(zip: '75020', lat: 33.7640, lng: -96.6090),
    _ZipMarkerData(zip: '75021', lat: 33.7920, lng: -96.5730),
  ];

  static const LatLng _initialMapCenter = LatLng(33.07, -96.80);

  @override
  void initState() {
    super.initState();
    _loadInitialListings();
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _extractZip(String text) {
    final trimmed = text.trim();
    if (RegExp(r'^\d{5}$').hasMatch(trimmed)) return trimmed;
    final match = RegExp(r'\b\d{5}\b').firstMatch(trimmed);
    return match?.group(0);
  }

  String? proxiedImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final encoded = Uri.encodeComponent(rawUrl);
    return "${ApiService.baseUrl}/image-proxy?url=$encoded";
  }

  double _scoreForListing(Listing l) {
    final seed = l.id.hashCode;
    return (seed.abs() % 101).toDouble();
  }

  _ZipMarkerData? _zipData(String zip) {
    for (final item in _zipLocations) {
      if (item.zip == zip) return item;
    }
    return null;
  }

  Widget _investmentBar(double score) {
    final s = score.clamp(0, 100);
    final t = s / 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final knobX = (width * t).clamp(0.0, width);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEF4444),
                    Color(0xFFF59E0B),
                    Color(0xFF10B981),
                  ],
                ),
              ),
            ),
            Positioned(
              left: knobX - 6,
              top: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.black26),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadInitialListings() async {
    setState(() {
      loadingListings = true;
      listingsError = null;
      status = "Loading listings...";
      listings = [];
    });

    try {
      final results = await ApiService.searchListings(limit: 12);
      setState(() {
        listings = results;
        status = results.isEmpty
            ? "No listings available."
            : "Showing ${results.length} listings";
      });
    } catch (_) {
      setState(() {
        listings = [];
        listingsError = "Listings are temporarily unavailable.";
        status = "Search by ZIP to view area intelligence.";
      });
    } finally {
      setState(() => loadingListings = false);
    }
  }

  void onSearchChanged(String value) {
    debounce?.cancel();
    final q = value.trim();

    if (q.isEmpty) {
      setState(() {
        suggestions = [];
        selected = null;
        status = "Search for a property address or ZIP";
      });
      return;
    }

    final zip = _extractZip(q);
    if (zip != null) {
      setState(() {
        suggestions = [];
        status = "Ready to search ZIP $zip";
      });
      return;
    }

    if (q.length < 3) {
      setState(() => suggestions = []);
      return;
    }

    debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ApiService.autocomplete(q);
        setState(() {
          suggestions = results;
          if (results.isNotEmpty) {
            status = "Select an address (or press Enter to search)";
          }
        });
      } catch (_) {
        setState(() {
          suggestions = [];
          if (_extractZip(q) == null) {
            status =
                "Address suggestions are unavailable right now. You can still search by ZIP.";
          }
        });
      }
    });
  }

  void selectSuggestion(AddressSuggestion s) {
    setState(() {
      selected = s;
      searchController.text = s.formatted;
      suggestions = [];
      _showStats = true;
    });

    _runSearch(query: s.formatted);
  }

  Future<void> _runSearch({String? query}) async {
    final q = (query ?? searchController.text).trim();
    final zip = _extractZip(q);

    setState(() {
      suggestions = [];
      listingsError = null;
      loadingListings = true;
      areaStats = null;
      statsError = null;
      _showStats = true;
      status = q.isEmpty ? "Searching..." : "Searching for \"$q\"...";
    });

    try {
      if (zip != null) {
        await _loadAreaStatsForZip(zip);

        try {
          final zipListings = await ApiService.searchListings(
            query: zip,
            limit: 12,
          );
          setState(() {
            listings = zipListings;
          });
        } catch (_) {
          setState(() {
            listings = [];
            listingsError = "Listings are temporarily unavailable for $zip.";
          });
        }

        setState(() {
          loadingListings = false;
          if (areaStats != null) {
            status = listings.isEmpty
                ? "Area snapshot loaded for $zip"
                : "Area snapshot loaded for $zip • ${listings.length} listings";
          } else if (statsError != null) {
            status = "Could not load area snapshot for $zip";
          }
        });

        return;
      }

      final results = await ApiService.searchListings(
        query: q.isEmpty ? null : q,
        limit: 12,
      );

      setState(() {
        listings = results;
        if (results.isEmpty) {
          status = "No listings found.";
        } else {
          status = "Showing ${results.length} listings";
        }
      });

      if (results.isNotEmpty) {
        await _loadAreaStatsForZip(results.first.zip);
      }
    } catch (e) {
      setState(() {
        listings = [];
        listingsError = "Listings are temporarily unavailable.";
        status = "Search failed: $e";
      });
    } finally {
      setState(() => loadingListings = false);
    }
  }

  Future<void> _loadAreaStatsForZip(String zip) async {
    setState(() {
      loadingStats = true;
      statsError = null;
      areaStats = null;
    });

    try {
      final s = await ApiService.fetchAreaStats(
        areaInput: zip,
        zipcode: zip,
      );

      setState(() {
        areaStats = s;
        statsError = null;
      });
    } catch (e) {
      setState(() {
        statsError = "Area snapshot unavailable for $zip: $e";
        areaStats = null;
      });
    } finally {
      setState(() => loadingStats = false);
    }
  }

  Future<void> _searchZipFromExplorer(String zip) async {
    final zipPoint = _zipData(zip);

    setState(() {
      _activeMapZip = zip;
      searchController.text = zip;
      selected = null;
      suggestions = [];
      _showStats = true;
      status = "Loading analytics for ZIP $zip...";
    });

    if (zipPoint != null) {
      _mapController.move(LatLng(zipPoint.lat, zipPoint.lng), 10.8);
    }

    await _runSearch(query: zip);

    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;
    final context = _statsKey.currentContext;
    if (context != null && context.mounted) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _clearSearch() {
    setState(() {
      searchController.clear();
      suggestions = [];
      selected = null;
      listings = [];
      listingsError = null;
      areaStats = null;
      statsError = null;
      _showStats = false;
      _activeMapZip = null;
      status = "Search for a property address or ZIP";
    });

    _mapController.move(_initialMapCenter, 8.7);
    _loadInitialListings();
  }

  Widget _buildHeroSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A),
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'PropertyIQ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Search ZIP codes, explore market intelligence, compare areas, and discover property opportunities with a more visual experience.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopZipCodesSection(ThemeData theme) {
    final textPrimary = theme.textTheme.bodyLarge?.color;
    final textSecondary = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: theme.primaryColor),
              const SizedBox(width: 10),
              Text(
                'Top 5 ZIP Codes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Click any ZIP code below to run the same area search instantly.',
            style: TextStyle(
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _topZipCodes.map((item) {
              final zip = item['zip']!;
              final error = item['error']!;
              final color = theme.primaryColor;
              final isActive = _activeMapZip == zip;

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _searchZipFromExplorer(zip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.78)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isActive ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: isActive ? 0.35 : 0.22),
                        blurRadius: isActive ? 18 : 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zip, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Prediction Error', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(error, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLegendChip(Color color, String label, Color? textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZipMapSection(ThemeData theme) {
    final textPrimary = theme.textTheme.bodyLarge?.color;
    final textSecondary = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8);
    final isDark = theme.brightness == Brightness.dark;

    final markers = _zipLocations.map((point) {
      final isActive = _activeMapZip == point.zip;
      return Marker(
        point: LatLng(point.lat, point.lng),
        width: isActive ? 108 : 92,
        height: isActive ? 52 : 46,
        child: _RealMapZipMarker(
          zip: point.zip,
          color: theme.primaryColor.withValues(alpha: 0.5), // Softened inactive color
          active: isActive,
          activeColor: theme.primaryColor,
          onTap: () => _searchZipFromExplorer(point.zip),
        ),
      );
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.cardTheme.color,
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, color: theme.primaryColor),
              const SizedBox(width: 10),
              Text(
                'ZIP Map Explorer',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Explore ZIP codes on a real map. Click any marker to load the same analytics and listings as a manual ZIP search.',
            style: TextStyle(
              color: textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMapLegendChip(const Color(0xFF2563EB), 'Top ZIP', textPrimary),
              _buildMapLegendChip(const Color(0xFF16A34A), 'Growth', textPrimary),
              _buildMapLegendChip(const Color(0xFFEA580C), 'Hot area', textPrimary),
              _buildMapLegendChip(theme.primaryColor, 'Selected ZIP', textPrimary),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 500,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _initialMapCenter,
                  initialZoom: 8.7,
                  minZoom: 7.5,
                  maxZoom: 15,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.propertyiq.frontend',
                  ),
                  MarkerLayer(markers: markers),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    final textPrimary = theme.textTheme.bodyLarge?.color;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Market Intelligence',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: TextStyle(color: textPrimary),
                  onSubmitted: (_) {
                    debounce?.cancel();
                    setState(() => suggestions = []);
                    _runSearch();
                  },
                  decoration: InputDecoration(
                    hintText: "Search ZIP or address",
                    hintStyle: TextStyle(color: textPrimary?.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC),
                    prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.primaryColor, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  debounce?.cancel();
                  setState(() => suggestions = []);
                  _runSearch();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Search"),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _clearSearch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: const Text("Clear"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (suggestions.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: Card(
                elevation: 0,
                color: isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.dividerColor),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: suggestions
                      .map((s) => ListTile(
                            leading: Icon(Icons.location_on_outlined, color: theme.primaryColor),
                            title: Text(s.formatted, style: TextStyle(color: textPrimary)),
                            onTap: () => selectSuggestion(s),
                          ))
                      .toList(),
                ),
              ),
            ),
          if (suggestions.isNotEmpty) const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? theme.primaryColor.withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? theme.primaryColor.withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? theme.primaryColor : const Color(0xFF1E3A8A),
                  ),
                ),
                if (listingsError != null) ...[
                  const SizedBox(height: 6),
                  Text(listingsError!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget listingCard(Listing l, ThemeData theme) {
    final title = "${l.address}, ${l.city} ${l.state} ${l.zip}";
    final beds = l.beds?.toStringAsFixed(0) ?? "-";
    final baths = l.baths?.toStringAsFixed(1) ?? "-";
    final sqft = l.sqft?.toString() ?? "-";
    final img = proxiedImageUrl(l.photo);
    final score = _scoreForListing(l);
    final zipcode = l.zip;
    
    final textPrimary = theme.textTheme.bodyLarge?.color;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      color: theme.cardTheme.color,
      shadowColor: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (img != null)
                  Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: const Center(
                          child: Text("Image unavailable"),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    color: Colors.grey.withValues(alpha: 0.1),
                    child: const Center(child: Text("No image")),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      zipcode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(Icons.bed_outlined, "Beds: $beds", theme),
                    _infoChip(Icons.bathtub_outlined, "Baths: $baths", theme),
                    _infoChip(Icons.square_foot_outlined, "Sqft: $sqft", theme),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? theme.primaryColor.withValues(alpha: 0.15) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? theme.primaryColor.withValues(alpha: 0.3) : const Color(0xFFBBF7D0)),
                  ),
                  child: Center(
                    child: Text(
                      l.price != null
                          ? "Price: ${_currency.format(l.price)}"
                          : "Price: -",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? theme.primaryColor : const Color(0xFF166534),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Investment Score",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _investmentBar(score),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text("Analyze Area"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      side: BorderSide(color: theme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: zipcode.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AreaReportPage(areaInput: zipcode),
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.textTheme.bodyLarge?.color;
    final textSecondary = theme.textTheme.bodyMedium?.color;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(theme),
                  const SizedBox(height: 18),
                  _buildZipMapSection(theme),
                  const SizedBox(height: 18),
                  _buildTopZipCodesSection(theme),
                  const SizedBox(height: 18),
                  _buildSearchSection(theme),
                  const SizedBox(height: 14),
                  if (_showStats) ...[
                    Container(
                      key: _statsKey,
                      child: AreaStatsPanel(
                        stats: areaStats,
                        loading: loadingStats,
                        error: statsError,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (loadingListings)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            if (!loadingListings && listings.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      areaStats != null
                          ? "Area snapshot loaded, but no listings matched this search."
                          : "No listings to display yet.",
                      style: TextStyle(
                        fontSize: 16,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else if (!loadingListings)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.home_work_outlined, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        "Property Listings",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!loadingListings && listings.isNotEmpty)
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final crossAxisCount = width < 900 ? 1 : 2;

                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => listingCard(listings[i], theme),
                      childCount: listings.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: crossAxisCount == 1 ? 1.12 : 0.70,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ZipMarkerData {
  final String zip;
  final double lat;
  final double lng;

  const _ZipMarkerData({
    required this.zip,
    required this.lat,
    required this.lng,
  });
}

class _RealMapZipMarker extends StatelessWidget {
  final String zip;
  final Color color;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _RealMapZipMarker({
    required this.zip,
    required this.color,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? activeColor : color.withValues(alpha: 0.60),
              width: active ? 2 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: (active ? activeColor : color)
                    .withValues(alpha: active ? 0.30 : 0.18),
                blurRadius: active ? 16 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: active ? Colors.white : color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                zip,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}