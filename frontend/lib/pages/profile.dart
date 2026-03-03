import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/listing.dart';
import '../services/saved_listings_store.dart';
import '../theme.dart'; // Added for AppTheme
import '../app.dart';   // Added for themeNotifier

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

  // --- Theme Selection Methods ---
  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Theme"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeTile(context, "Classic Light", AppTheme.classicLight, Colors.blue),
            _themeTile(context, "Soft Blue", AppTheme.softBlue, Colors.cyan),
            _themeTile(context, "Deep Dark", AppTheme.deepDark, Colors.grey.shade900),
            _themeTile(context, "Midnight", AppTheme.midnight, Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _themeTile(BuildContext context, String title, AppTheme value, Color color) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 10),
      title: Text(title),
      onTap: () {
        themeNotifier.value = value;
        Navigator.pop(context);
      },
    );
  }
  // -------------------------------

  @override
  Widget build(BuildContext context) {
    final saved = SavedListingsStore.saved;

    return Scaffold(
      // The AppBar holds your new Theme button in the top right
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Tooltip(
              message: "Change App Theme",
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showThemeDialog(context),
                hoverColor: Colors.grey.withOpacity(0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.palette_outlined, size: 20),
                      SizedBox(width: 6),
                      Text("Theme", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      
      // The body conditionally shows either the empty state or your saved listings
      body: saved.isEmpty
          ? const Center(
              child: Text(
                "No saved properties yet.\nTap the heart on a listing to save it.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Saved Properties",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: saved.length,
                      itemBuilder: (context, i) {
                        final Listing l = saved[i];
                        final title = "${l.address}, ${l.city} ${l.state} ${l.zip}";
                        final beds = l.beds?.toStringAsFixed(0) ?? "-";
                        final baths = l.baths?.toStringAsFixed(1) ?? "-";
                        final sqft = l.sqft?.toString() ?? "-";
                        final price = l.price == null ? "-" : _currency.format(l.price);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Address
                                Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 10),
                                const Divider(),
                                const SizedBox(height: 10),

                                // Beds / Baths / Sqft
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Beds: $beds"),
                                    Text("Baths: $baths"),
                                    Text("Sqft: $sqft"),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(),
                                const SizedBox(height: 10),

                                // Price
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Price",
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      price,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(),
                                const SizedBox(height: 6),

                                // Remove button
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      SavedListingsStore.removeById(l.id);
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text("Remove"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        SavedListingsStore.clear();
                        setState(() {});
                      },
                      child: const Text("Clear all"),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
