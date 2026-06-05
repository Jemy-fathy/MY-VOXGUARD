import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../trust_contacts/add_contact_screen.dart'; 
import '../../custom_widgets/custom_button.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  List<dynamic> contacts = [];
  bool isLoading = true;
 
  final String baseUrl = "http://192.168.1.191:8000";

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      var response = await Dio().get(
        "$baseUrl/api/trusted-contacts/index",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      
      if (mounted) {
        setState(() {
          contacts = response.data['contacts'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint("Error Fetching: $e");
    }
  }

  Future<void> _deleteContact(dynamic id, int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      
      await Dio().delete(
        "$baseUrl/api/trusted-contacts/${id.toString()}",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact removed successfully"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      _fetchContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete contact"), backgroundColor: Colors.orange),
        );
      }
      debugPrint("Error Deleting: $e");
    }
  }

  void _showDeleteConfirmation(dynamic id, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this contact?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => contacts.removeAt(index)); 
              _deleteContact(id, index); 
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF8E9EFE), Color(0xFFE040FB)]),
            ),
          ),
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30), 
                      topRight: Radius.circular(30)
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : contacts.isEmpty
                                ? const Center(child: Text("No contacts added yet"))
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: contacts.length,
                                    itemBuilder: (context, index) {
                                      return _buildContactCard(contacts[index], index);
                                    },
                                  ),
                      ),
                      const SizedBox(height: 10),
                      CustomButton(
                        text: "Add new",
                        onPressed: () async {
                          bool? refresh = await Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const AddContactScreen())
                          );
                          if (refresh == true || !mounted) {
                            _fetchContacts();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 140,
      padding: const EdgeInsets.only(top: 60, left: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30), 
            onPressed: () => Navigator.pop(context)
          ),
          const Text(
            'Trusted Contacts', 
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(dynamic contact, int index) {
    String imageUrl = contact['image'] ?? "";
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = "$baseUrl$imageUrl";
    }

    String name = contact['name'] ?? "${contact['first_name'] ?? ''} ${contact['last_name'] ?? ''}".trim();
    if (name.isEmpty) name = "Unknown Name";

    String status = (contact['status'] ?? "offline").toLowerCase();
    Color statusColor = status == "online" ? Colors.green : (status == "nearby" ? Colors.purple : Colors.grey);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl, 
                        width: 60, height: 60, 
                        fit: BoxFit.cover, 
                        errorBuilder: (c, e, s) => _buildPlaceholder()
                      )
                    : _buildPlaceholder(),
              ),
              Positioned(
                right: 2, bottom: 2,
                child: Container(
                  width: 12, height: 12, 
                  decoration: BoxDecoration(
                    color: statusColor, 
                    shape: BoxShape.circle, 
                    border: Border.all(color: Colors.white, width: 2)
                  )
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)
                ),
                Text(
                  contact['relation'] ?? "Relative", 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)
                ),
                Text(
                  contact['phone'] ?? "No Phone", 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmation(contact['id'], index);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Delete", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
    width: 60, height: 60, 
    color: Colors.grey[200], 
    child: const Icon(Icons.person, color: Colors.grey)
  );
}