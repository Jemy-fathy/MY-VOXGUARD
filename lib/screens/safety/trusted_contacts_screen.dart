import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../trust_contacts/add_contact_screen.dart';
import '../../custom_widgets/custom_button.dart';
import '../../config/api_config.dart';

class TrustedContactsScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const TrustedContactsScreen({super.key, this.onBackPressed});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  List<dynamic> contacts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalContacts();
    _fetchContacts();
  }

  Future<void> _loadLocalContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localData = prefs.getString('local_trusted_contacts');
    if (localData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(localData);
        if (mounted) {
          setState(() {
            contacts = decoded;
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading local contacts: $e");
      }
    }
  }

  Future<void> _fetchContacts() async {
    if (!mounted) return;
    if (contacts.isEmpty) {
      setState(() => isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token') ?? prefs.getString('auth_token');

      var response = await Dio().get(
        "${ApiConfig.baseUrl}/trusted-contacts",
        options: Options(
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (mounted) {
        setState(() {
          if (response.data is Map && response.data['contacts'] != null) {
            contacts = response.data['contacts'];
          } else {
            contacts = [];
          }
          isLoading = false;
        });
        await prefs.setString('local_trusted_contacts', jsonEncode(contacts));
      }
    } catch (e) {
      await _loadLocalContacts();
    }
  }

  Future<void> _deleteContact(dynamic id) async {
    // Delete locally first so UI updates instantly
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      contacts.removeWhere((c) => c['id'] == id);
    });
    await prefs.setString('local_trusted_contacts', jsonEncode(contacts));

    try {
      final String? token = prefs.getString('token') ?? prefs.getString('auth_token');

      var response = await Dio().delete(
        "${ApiConfig.baseUrl}/trusted-contacts/$id",
        options: Options(
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trusted contact has been removed successfully'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
        _fetchContacts();
      } else {
        throw Exception("Delete rejected by backend");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contact deleted locally. Server update pending.'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _confirmDeleteContact(dynamic id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("confirm".tr()),
          content: Text("delete_contact_confirm".tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("no".tr()),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteContact(id);
              },
              child: Text("yes".tr(), style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
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
              gradient: LinearGradient(
                colors: [Color(0xFF8E9EFE), Color(0xFFE040FB)],
              ),
            ),
          ),
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : contacts.isEmpty
                                ? const SizedBox.shrink()
                                : ListView.builder(
                                    itemCount: contacts.length,
                                    itemBuilder: (context, index) => _buildContactCard(contacts[index]),
                                  ),
                      ),
                      CustomButton(
                        text: "add_new".tr(),
                        onPressed: () async {
                          bool? refresh = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddContactScreen(
                                onBackPressed: widget.onBackPressed,
                              ),
                            ),
                          );
                          if (refresh == true) _fetchContacts();
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
    bool isAr = context.locale.languageCode == 'ar';
    return Container(
      height: 140,
      padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
      child: Row(
        textDirection: isAr ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 24,
            ),
            onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text('trusted_contacts_title'.tr(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _localizeDigits(String input) {
    if (context.locale.languageCode != 'ar') return input;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  Widget _buildContactCard(dynamic contact) {
  String imageUrl = contact['image'] ?? "";
  String name = "${contact['first_name'] ?? ''} ${contact['last_name'] ?? ''}".trim();
  if (name.isEmpty) name = contact['name'] ?? "no_name".tr();
  
  String statusKey = (contact['status'] ?? "offline").toLowerCase();
  
  Color statusColor = Colors.grey;
  if (statusKey == "online") statusColor = Colors.green;
  if (statusKey == "nearby") statusColor = Colors.purple;

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
          offset: const Offset(0, 4),
        ),
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
                  ? (imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                        )
                      : Image.file(
                          File(imageUrl),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                        ))
                  : _buildPlaceholder(),
            ),

            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              Text(
                (contact['relation'] ?? "relative").toString().tr(),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              Text(
                _localizeDigits(contact['phone'] ?? "no_phone".tr()),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              statusKey.tr(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _confirmDeleteContact(contact['id']),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 24,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildPlaceholder() {
  return Container(
    width: 60,
    height: 60,
    color: Colors.grey[200],
    child: const Icon(Icons.person, color: Colors.grey),
  );
}
}
