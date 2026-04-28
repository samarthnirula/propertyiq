import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/listing.dart';
import '../services/saved_listings_store.dart';
import '../theme.dart';
import '../app.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);

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
            _themeTile(context, "Deep Dark", AppTheme.deepDark, Colors.indigo),
            _themeTile(context, "Midnight", AppTheme.midnight, Colors.deepPurple),
          ],
        ),
      ),
    );
  }

  Widget _themeTile(
    BuildContext context,
    String title,
    AppTheme value,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 10),
      title: Text(title),
      onTap: () {
        themeNotifier.value = value;
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = SavedListingsStore.saved;
    final theme = Theme.of(context);

    return Scaffold(
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
                hoverColor: Colors.grey.withAlpha(51),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 20,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Theme",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${l.address}, ${l.city} ${l.state} ${l.zip}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Beds: ${l.beds ?? '-'}"),
                                    Text("Baths: ${l.baths ?? '-'}"),
                                    Text("Sqft: ${l.sqft ?? '-'}"),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Price"),
                                    Text(
                                      l.price == null
                                          ? "-"
                                          : _currency.format(l.price),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      SavedListingsStore.removeById(l.id);
                                      setState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      "Remove",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        SavedListingsStore.clear();
                        setState(() {});
                      },
                      child: const Text(
                        "Clear all",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}