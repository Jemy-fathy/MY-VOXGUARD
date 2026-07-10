import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/colors.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  int _selectedIndex = 0;

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'flag': 'images/EN.png', 'locale': 'en'},
    {'name': 'Arabic', 'flag': 'images/Egypt.png', 'locale': 'ar'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize selected index based on current locale
    final currentLocale = context.locale.languageCode;
    setState(() {
      _selectedIndex = _languages.indexWhere(
        (lang) => lang['locale'] == currentLocale,
      );
      if (_selectedIndex == -1) _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgBlueLight,
              AppColors.bgPurpleLight,
              Colors.white,
            ],
            stops: [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.black87,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    const LinearGradient(
                      colors: [
                        Color(0XFF4983F6),
                        Color(0xFFC175F5),
                        Color(0XFFFBACB7),
                      ],
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                child: Text(
                  'language'.tr(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(
                height: 240,
              ), // Reduced height to see options better
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: ListView.builder(
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          _buildLanguageTile(
                            index: index,
                            name: _languages[index]['name']!,
                            flagAsset: _languages[index]['flag']!,
                          ),
                          Divider(
                            color: const Color(0xFFC175F5).withOpacity(0.6),
                            height: 1,
                            thickness: 1.5,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD546F3), Color(0xFFBD3CD9)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0XFF4983F6),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () async {
                      final selectedLocale =
                          _languages[_selectedIndex]['locale']!;
                      await context.setLocale(Locale(selectedLocale));
                      if (!mounted) return;
                      // Navigate back to Splash and clear stack
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (route) => false,
                      );
                    },
                    child: Text(
                      'confirm'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile({
    required int index,
    required String name,
    required String flagAsset,
  }) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Image.asset(
              flagAsset,
              width: 32,
              height: 24,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.flag, size: 32, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.black.withOpacity(0.9)
                      : Colors.black45,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFD546F3),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
