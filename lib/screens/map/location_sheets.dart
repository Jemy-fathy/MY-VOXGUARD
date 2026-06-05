import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/colors.dart'; 

class LocationSheets {
  static double _selectedRadius = 250.0;
  static bool _notifyContacts = true;

  static void showMarkLocationOptions(
      BuildContext context, LatLng position, String placeName, Function(double radius, String type, bool notifyAndTriggerSos) onSave) {
    
    _selectedRadius = 250.0;
    _notifyContacts = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          ),
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              Text(
                placeName.isEmpty ? "Selected Location" : placeName, 
                textAlign: TextAlign.center, 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
              ),
              const Text("Location detected", style: TextStyle(color: Colors.grey)), 
              const SizedBox(height: 35),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildZoneOption(
                    icon: Icons.add,
                    label: "Add as a new\nsafe zone",
                    color: Colors.blue, 
                    onTap: () => _showRadiusSettings(context, position, "safe", placeName, onSave),
                  ),
                  _buildZoneOption(
                    icon: Icons.add,
                    label: "Add as a new\nred zone",
                    color: Colors.red, 
                    onTap: () => _showRadiusSettings(context, position, "red", placeName, onSave),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  static void _showRadiusSettings(
      BuildContext context, LatLng position, String type, String placeName, Function(double radius, String type, bool notifyAndTriggerSos) onSave) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
              ),
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHandle(),
                  Center(
                    child: Text(
                      placeName.isEmpty ? "Selected Location" : placeName, 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                    )
                  ),
                  const SizedBox(height: 35),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Set Radius", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
                      Text("${_selectedRadius.toInt()}m", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
                    ],
                  ),
                  Slider(
                    value: _selectedRadius,
                    min: 50, max: 1500,
                    activeColor: AppColors.primaryPurple,
                    inactiveColor: AppColors.primaryPurple.withOpacity(0.2),
                    onChanged: (val) => setModalState(() => _selectedRadius = val),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Notify Trust contacts on Entry", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        Switch(
                          value: _notifyContacts,
                          activeColor: AppColors.primaryPurple,
                          onChanged: (val) => setModalState(() => _notifyContacts = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: AppColors.buttonBorderBlue, width: 1),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        onSave(_selectedRadius, type, _notifyContacts);
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Save ${type == 'safe' ? 'safe' : 'red'} zone", 
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildZoneOption({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(color: color.withOpacity(0.4), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 40),
        ),
        const SizedBox(height: 10),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  static Widget _buildHandle() => Center(child: Container(margin: const EdgeInsets.only(bottom: 15), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))));
}