import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart'; 
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManagePlacesScreen extends StatefulWidget {
  final Map<String, LatLng> places;
  final List<Map<String, dynamic>> customZones; 
  final Function(String) onDelete;
  final Function(String) onDeleteZone; 
  final Function(LatLng) onPlaceSelected; 

  const ManagePlacesScreen({
    super.key,
    required this.places,
    required this.customZones,
    required this.onDelete,
    required this.onDeleteZone,
    required this.onPlaceSelected, 
  });

  @override
  State<ManagePlacesScreen> createState() => _ManagePlacesScreenState();
}

class _ManagePlacesScreenState extends State<ManagePlacesScreen> {
  final String _baseUrl = "http://192.168.1.191:8000/api";
  bool _isDeletingZone = false;

  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String subLocality = place.subLocality ?? ""; 
        String locality = place.locality ?? "";      

        if (subLocality.isNotEmpty) {
          return "$subLocality, $locality";
        } else {
          return "${place.street ?? "Unknown Street"}, $locality";
        }
      }
    } catch (e) {
      return "Address not available";
    }
    return "Unknown Location";
  }

  Future<void> _deleteZoneFromServer(String circleIdStr) async {
    if (!circleIdStr.contains('server_')) {
      widget.onDeleteZone(circleIdStr);
      setState(() {});
      return;
    }

    final List<String> parts = circleIdStr.split('_');
    final String backendId = parts.last; 

    setState(() => _isDeletingZone = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('auth_token');

      final response = await http.delete(
        Uri.parse("$_baseUrl/zones/$backendId"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        widget.onDeleteZone(circleIdStr); 
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Zone deleted successfully")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error deleting zone: $e");
    } finally {
      setState(() => _isDeletingZone = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int placesCount = widget.places.length;
    final int zonesCount = widget.customZones.length;
    final int totalCount = placesCount + zonesCount;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () => Navigator.pop(context))
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const Center(child: Icon(Icons.stars_rounded, color: Colors.orange, size: 80)),
              const SizedBox(height: 10),
              const Text("Safe Places", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text("$totalCount locations secured", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 25),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: totalCount == 0
                      ? _buildEmptyState()
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: ListView.separated(
                            itemCount: totalCount,
                            separatorBuilder: (context, index) => Divider(height: 1, thickness: 1, indent: 70, color: Colors.grey[50]),
                            itemBuilder: (context, index) {
                              if (index < placesCount) {
                                String key = widget.places.keys.elementAt(index);
                                LatLng latLng = widget.places[key]!;
                                IconData icon = key == "Home" ? Icons.home_rounded : (key == "Work" ? Icons.work_rounded : Icons.location_on_rounded);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                  onTap: () {
                                    widget.onPlaceSelected(latLng);
                                    Navigator.pop(context);
                                  },
                                  leading: CircleAvatar(
                                      backgroundColor: Colors.pink.withOpacity(0.1),
                                      child: Icon(icon, color: Colors.pink, size: 20)),
                                  title: Text(key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: FutureBuilder<String>(
                                    future: _getAddressFromLatLng(latLng),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? "Locating...",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        widget.onDelete(key);
                                        setState(() {});
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            SizedBox(width: 10),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                final zoneIndex = index - placesCount;
                                final zone = widget.customZones[zoneIndex];
                                bool isDanger = zone['isDanger'] ?? false;
                                String circleIdStr = zone['id'].toString();

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                  onTap: () {
                                    widget.onPlaceSelected(LatLng(zone['lat'], zone['lng']));
                                    Navigator.pop(context);
                                  },
                                  leading: CircleAvatar(
                                      backgroundColor: (isDanger ? Colors.red : Colors.green).withOpacity(0.1),
                                      child: Icon(
                                        isDanger ? Icons.gpp_bad_rounded : Icons.gpp_good_rounded, 
                                        color: isDanger ? Colors.red : Colors.green, 
                                        size: 20
                                      )),
                                  title: Text(zone['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    isDanger ? "Danger Zone" : "Safe Zone", 
                                    style: TextStyle(fontSize: 12, color: isDanger ? Colors.red : Colors.green),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    onSelected: (value) async {
                                      if (value == 'delete') {
                                        await _deleteZoneFromServer(circleIdStr);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            SizedBox(width: 10),
                                            Text('Delete', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                ),
              ),
              _buildAddButton(),
            ],
          ),
          if (_isDeletingZone)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text("No places saved yet.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 35, top: 25),
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context, true); 
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
            border: Border.all(color: Colors.blueAccent.withOpacity(0.1), width: 1),
          ),
          child: const Icon(Icons.add_location_alt_outlined, size: 28, color: Colors.blueAccent),
        ),
      ),
    );
  }
}