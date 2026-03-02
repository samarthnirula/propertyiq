import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/address_suggesstion.dart';
import '../models/listing.dart';
import 'package:intl/intl.dart';
import '../models/area_stats.dart';
import '../services/saved_listings_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController searchController = TextEditingController();
  Timer? debounce;

  List<AddressSuggestion> suggestions = [];
  AddressSuggestion? selected;

  List<Listing> listings = [];
  bool loadingListings = false;

  String status = "Search for a property address";
  AreaStats? areaStats;
  bool loadingStats = false;
  String? statsError;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadInitialListings();
  }

  Future<void> _loadInitialListings() async {
    setState(() {
      loadingListings = true;
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
    } catch (e) {
      setState(() {
        status = "Listings error: $e";
      });
    } finally {
      setState(() {
        loadingListings = false;
      });
    }
  }

  void onSearchChanged(String value) {
    debounce?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        suggestions = [];
        selected = null;
        status = "Search for a property address";
      });
      return;
    }

    if (value.trim().length < 3) {
      setState(() => suggestions = []);
      return;
    }

    debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ApiService.autocomplete(value.trim());
        setState(() {
          suggestions = results;
          status = results.isEmpty
              ? "No suggestions found"
              : "Select an address (or press Enter to search)";
        });
      } catch (e) {
        setState(() {
          suggestions = [];
          status = "Autocomplete error: $e";
        });
      }
    });
  }

  Future<void> _runSearch({String? query}) async {
    final q = (query ?? searchController.text).trim();

    setState(() {
      suggestions = [];
      statsError = null;
      areaStats = null;
      loadingStats = q.isNotEmpty;
      loadingListings = true;
      listings = [];
      status = q.isEmpty ? "Fetching listings..." : "Searching listings...";
    });

    final listingsFuture =
        ApiService.searchListings(query: q.isEmpty ? null : q, limit: 12);

    final statsFuture = q.isEmpty
        ? Future<AreaStats?>.value(null)
        : ApiService.fetchAreaStats(q: q);

    try {
      final results = await Future.wait([listingsFuture, statsFuture]);

      final listingResults = results[0] as List<Listing>;
      final statsResults = results[1] as AreaStats?;

      setState(() {
        listings = listingResults;
        areaStats = statsResults;
        status = listingResults.isEmpty
            ? (q.isEmpty
                ? "No listings found."
                : "No listings found for \"$q\".")
            : "Listings found: ${listingResults.length}";
      });
    } catch (e) {
      setState(() {
        status = "Search error: $e";
        statsError = e.toString();
      });
    } finally {
      setState(() {
        loadingListings = false;
        loadingStats = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      searchController.clear();
      suggestions = [];
      selected = null;
      status = "Search for a property address";
    });
    _loadInitialListings();
  }

  String? proxiedImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final encoded = Uri.encodeComponent(rawUrl);
    return "${ApiService.baseUrl}/image-proxy?url=$encoded";
  }

  double _scoreForListing(Listing l) {
    final seed = (l.id ?? "").hashCode;
    return (seed.abs() % 101).toDouble();
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
                  colors: [Colors.red, Colors.yellow, Colors.green],
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

  Widget listingCard(Listing l) {
    final title = "${l.address}, ${l.city} ${l.state} ${l.zip}";
    final beds = l.beds?.toStringAsFixed(0) ?? "-";
    final baths = l.baths?.toStringAsFixed(1) ?? "-";
    final sqft = l.sqft?.toString() ?? "-";
    final img = proxiedImageUrl(l.photo);
    final score = _scoreForListing(l);
    final isSaved = SavedListingsStore.isSaved(l);

    return Card(
      clipBehavior: Clip.antiAlias,
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
                  Image.network(img, fit: BoxFit.cover)
                else
                  const Center(child: Text("No image")),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      color: isSaved ? Colors.red : Colors.white,
                    ),
                    onPressed: () {
                      SavedListingsStore.toggle(l);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text("Beds: $beds")),
                    Expanded(child: Text("Baths: $baths")),
                    Expanded(child: Text("Sqft: $sqft")),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    l.price != null
                        ? "Price: ${_currency.format(l.price)}"
                        : "Price: -",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                _investmentBar(score),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Find a Property",
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        onSubmitted: (_) => _runSearch(),
                        decoration: const InputDecoration(
                          labelText: "Search address / keyword",
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: loadingListings ? null : _runSearch,
                      child: const Text("Search"),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: loadingListings ? null : _clearSearch,
                      child: const Text("Clear"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(status),
                const SizedBox(height: 12),
                if (loadingListings)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 4),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) => listingCard(listings[i]),
                childCount: listings.length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 450,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}