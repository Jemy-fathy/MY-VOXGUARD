import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl_phone_field/countries.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/custom_text_field.dart';
import '../../custom_widgets/logo_header.dart';
import '../../config/api_config.dart';

class ArabicDigitsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    
    String newText = newValue.text;
    for (int i = 0; i < english.length; i++) {
      newText = newText.replaceAll(english[i], arabic[i]);
    }
    
    return newValue.copyWith(
      text: newText,
      selection: newValue.selection,
    );
  }
}

class AddContactScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const AddContactScreen({super.key, this.onBackPressed});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController relationController = TextEditingController();
  String fullPhoneNumber = "";
  String currentCountryCode = "+20";
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final String apiUrl = "${ApiConfig.baseUrl}/trusted-contacts/store";

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,   // ضغط الصورة 70%
      maxWidth: 1024,     // الحد الأقصى للعرض
      maxHeight: 1024,    // الحد الأقصى للطول
    );
    if (pickedFile != null) {
      if (!mounted) return;
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _saveContact() async {
    if (firstNameController.text.isEmpty || fullPhoneNumber.isEmpty || relationController.text.isEmpty) {
      _showSnackBar("fill_all_fields".tr(), Colors.orange);
      return;
    }

    String phoneToSend = fullPhoneNumber;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabic.length; i++) {
      phoneToSend = phoneToSend.replaceAll(arabic[i], english[i]);
    }

    _showLoadingDialog();

    try {
      final prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? "";
      String savedUserId = prefs.get('user_id')?.toString() ?? "";

      print("DEBUG: Sending request to $apiUrl");
      print("DEBUG: Token: $token");
      print("DEBUG: User ID: $savedUserId");

      FormData formData = FormData.fromMap({
        "user_id": savedUserId,
        "name": "${firstNameController.text} ${lastNameController.text}".trim(),
        "phone": phoneToSend,
        "relation": relationController.text,
        "is_online": 0,
        "status": "offline",
      });

      if (_selectedImage != null) {
        // تحديد نوع الصورة بشكل صحيح
        String ext = _selectedImage!.path.split('.').last.toLowerCase();
        String mimeType;
        switch (ext) {
          case 'png':  mimeType = 'image/png';  break;
          case 'gif':  mimeType = 'image/gif';  break;
          case 'webp': mimeType = 'image/webp'; break;
          case 'heic': mimeType = 'image/heic'; break;
          default:     mimeType = 'image/jpeg'; break;
        }
        formData.files.add(MapEntry(
          "image",
          await MultipartFile.fromFile(
            _selectedImage!.path,
            filename: _selectedImage!.path.split('/').last,
            contentType: DioMediaType.parse(mimeType),
          ),
        ));
      }

      var dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      var response = await dio.post(
        apiUrl,
        data: formData,
        options: Options(
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); 

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> localContact = {
          "id": (response.data is Map && response.data['contact'] != null && response.data['contact']['id'] != null)
              ? response.data['contact']['id']
              : DateTime.now().millisecondsSinceEpoch,
          "name": "${firstNameController.text} ${lastNameController.text}".trim(),
          "phone": phoneToSend,
          "relation": relationController.text,
          "status": "offline",
          "image": _selectedImage != null ? _selectedImage!.path : "",
        };
        await _saveLocalContact(localContact);

        _showSnackBar("contact_saved_success".tr(), Colors.green);
        Navigator.pop(context, true); 
      } else {
        String errorMsg = "save_failed".tr();
        if (response.data != null && response.data is Map) {
          if (response.data['message'] != null) {
            errorMsg = response.data['message'];
          } else if (response.data['errors'] != null && response.data['errors'] is Map) {
            final errors = response.data['errors'] as Map;
            if (errors.isNotEmpty) {
              final firstError = errors.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                errorMsg = firstError.first.toString();
              } else {
                errorMsg = firstError.toString();
              }
            }
          }
        }
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        
        final Map<String, dynamic> localContact = {
          "id": DateTime.now().millisecondsSinceEpoch,
          "name": "${firstNameController.text} ${lastNameController.text}".trim(),
          "phone": phoneToSend,
          "relation": relationController.text,
          "status": "offline",
          "image": _selectedImage != null ? _selectedImage!.path : "",
        };
        await _saveLocalContact(localContact);

        _showSnackBar("Saved locally (offline mode)".tr(), Colors.orange);
        Navigator.pop(context, true); 
      }
    }
  }

  Future<void> _saveLocalContact(Map<String, dynamic> newContact) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? localData = prefs.getString('local_trusted_contacts');
      List<dynamic> localList = [];
      if (localData != null) {
        localList = jsonDecode(localData);
      }
      localList.add(newContact);
      await prefs.setString('local_trusted_contacts', jsonEncode(localList));
    } catch (e) {
      debugPrint("Error saving local contact: $e");
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating)
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
    );
  }

  String _localizeDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  // Comprehensive Arabic translations for countries
  final Map<String, String> _arabicCountryNames = {
    "AF": "أفغانستان", "AX": "جزر أولاند", "AL": "ألبانيا", "DZ": "الجزائر", "AS": "ساموا الأمريكية", "AD": "أندورا", "AO": "أنغولا", "AI": "أنغويلا", "AQ": "أنتاركتيكا", "AG": "أنتيغوا وبربودا", "AR": "الأرجنتين", "AM": "أرمينيا", "AW": "أروبا", "AU": "أستراليا", "AT": "النمسا", "AZ": "أذربيجان", "BS": "جزر البهاما", "BH": "البحرين", "BD": "بنجلاديش", "BB": "باربادوس", "BY": "بيلاروسيا", "BE": "بلجيكا", "BZ": "بليز", "BJ": "بنين", "BM": "برمودا", "BT": "بوتان", "BO": "بوليفيا", "BA": "البوسنة والهرسك", "BW": "بوتسوانا", "BV": "جزيرة بوفيه", "BR": "البرازيل", "IO": "إقليم المحيط الهندي البريطاني", "BN": "بروناي", "BG": "بلغاريا", "BF": "بوركينا فاسو", "BI": "بوروندي", "KH": "كمبوديا", "CM": "الكاميرون", "CA": "كندا", "CV": "الرأس الأخضر", "KY": "جزر كايمان", "CF": "جمهورية أفريقيا الوسطى", "TD": "تشاد", "CL": "تشيلي", "CN": "الصين", "CX": "جزيرة الكريسماس", "CC": "جزر كوكوس", "CO": "كولومبيا", "KM": "جزر القمر", "CG": "الكونغو", "CD": "الكونغو الديمقراطية", "CK": "جزر كوك", "CR": "كوستاريكا", "CI": "ساحل العاج", "HR": "كرواتيا", "CU": "كوبا", "CY": "قبرص", "CZ": "جمهورية التشيك", "DK": "الدنمارك", "DJ": "جيبوتي", "DM": "دومينيكا", "DO": "جمهورية الدومينيكان", "EC": "الإكوادور", "EG": "مصر", "SV": "السلفادور", "GQ": "غينيا الاستوائية", "ER": "إريتريا", "EE": "إستونيا", "ET": "إثيوبيا", "FK": "جزر فوكلاند", "FO": "جزر فارو", "FJ": "فيجي", "FI": "فنلندا", "FR": "فرنسا", "GF": "غويانا الفرنسية", "PF": "بولينيزيا الفرنسية", "TF": "الأقاليم الجنوبية الفرنسية", "GA": "الغابون", "GM": "غامبيا", "GE": "جورجيا", "DE": "ألمانيا", "GH": "غانا", "GI": "جبل طارق", "GR": "اليونان", "GL": "جرينلاند", "GD": "غرينادا", "GP": "غوادلوب", "GU": "غوام", "GT": "غواتيمالا", "GG": "غيرنزي", "GN": "غينيا", "GW": "غينيا بيساو", "GY": "غويانا", "HT": "هايتي", "HM": "جزيرة هيرد وجزر ماكدونالد", "VA": "الفاتيكان", "HN": "هندوراس", "HK": "هونج كونج", "HU": "المجر", "IS": "آيسلندا", "IN": "الهند", "ID": "إندونيسيا", "IR": "إيران", "IQ": "العراق", "IE": "أيرلندا", "IM": "جزيرة مان", "IL": "إسرائيل", "IT": "إيطاليا", "JM": "جامايكا", "JP": "اليابان", "JE": "جيرزي", "JO": "الأردن", "KZ": "كازاخستان", "KE": "كينيا", "KI": "كيريباتي", "KP": "كوريا الشمالية", "KR": "كوريا الجنوبية", "KW": "الكويت", "KG": "قيرغيزستان", "LA": "لاوس", "LV": "لاتفيا", "LB": "لبنان", "LS": "ليسوتو", "LR": "ليبيريا", "LY": "ليبيا", "LI": "ليختنشتاين", "LT": "ليتوانيا", "LU": "لوكسمبورغ", "MO": "ماكاو", "MK": "مقدونيا", "MG": "مدغشقر", "MW": "ملاوي", "MY": "ماليزيا", "MV": "جزر المالديف", "ML": "مالي", "MT": "مالطا", "MH": "جزر مارشال", "MQ": "مارتينيك", "MR": "موريتانيا", "MU": "موريشيوس", "YT": "مايوت", "MX": "المكسيك", "FM": "ميكرونيزيا", "MD": "مولدوفا", "MC": "موناكو", "MN": "منغوليا", "ME": "الجبل الأسود", "MS": "مونتسرات", "MA": "المغرب", "MZ": "موزمبيق", "MM": "ميانمار", "NA": "ناميبيا", "NR": "ناورو", "NP": "نيبال", "NL": "هولندا", "AN": "جزر الأنتيل الهولندية", "NC": "كاليدونيا الجديدة", "NZ": "نيوزيلندا", "NI": "نيكاراغوا", "NE": "النيجر", "NG": "نيجيريا", "NU": "نييوي", "NF": "جزيرة نورفولك", "MP": "جزر ماريانا الشمالية", "NO": "النرويج", "OM": "عمان", "PK": "باكستان", "PW": "بالاو", "PS": "فلسطين", "PA": "بنما", "PG": "بابوا غينيا الجديدة", "PY": "باراغواي", "PE": "بيرو", "PH": "الفلبين", "PN": "بيتكيرن", "PL": "بولندا", "PT": "البرتغال", "PR": "بورتوريكو", "QA": "قطر", "RE": "ريونيون", "RO": "رومانيا", "RU": "روسيا", "RW": "رواندا", "BL": "سان بارتليمي", "SH": "سانت هيلانة", "KN": "سانت كيتس ونيفيس", "LC": "سانت لوسيا", "MF": "سانت مارتن", "PM": "سان بيير وميكلون", "VC": "سانت فينسنت والغرينادين", "WS": "ساموا", "SM": "سان مارينو", "ST": "ساو تومي وبرينسيب", "SA": "السعودية", "SN": "السنغال", "RS": "صربيا", "SC": "سيشل", "SL": "سيراليون", "SG": "سنغافورة", "SK": "سلوفاكيا", "SI": "سلوفينيا", "SB": "جزر سليمان", "SO": "الصومال", "ZA": "جنوب أفريقيا", "GS": "جورجيا الجنوبية وجزر ساندويتش الجنوبية", "ES": "إسبانيا", "LK": "سريلانكا", "SD": "السودان", "SR": "سورينام", "SJ": "سفالبارد ويان ماين", "SZ": "سوازيلاند", "SE": "السويد", "CH": "سويسرا", "SY": "سوريا", "TW": "تايوان", "TJ": "طاجيكستان", "TZ": "تنزانيا", "TH": "تايلاند", "TL": "تيمور الشرقية", "TG": "توغو", "TK": "توكيلو", "TO": "تونغا", "TT": "ترينيداد وتوباغو", "TN": "تونس", "TR": "تركيا", "TM": "تركمانستان", "TC": "جزر تركس وكايكوس", "TV": "توفالو", "UG": "أوغندا", "UA": "أوكرانيا", "AE": "الإمارات العربية المتحدة", "GB": "المملكة المتحدة", "US": "الولايات المتحدة", "UM": "جزر الولايات المتحدة الصغيرة النائية", "UY": "أوروغواي", "UZ": "أوزبكستان", "VU": "فانواتو", "VE": "فنزويلا", "VN": "فيتنام", "VG": "جزر فيرجن البريطانية", "VI": "جزر فيرجن الأمريكية", "WF": "واليس وفوتونا", "EH": "الصحراء الغربية", "YE": "اليمن", "ZM": "زامبيا", "ZW": "زيمبابوي"
  };

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        bool isAr = context.locale.languageCode == 'ar';
        List<Country> allCountries = countries;
        
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 15),
                  Text("select_country".tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: allCountries.length,
                      itemBuilder: (context, index) {
                        var c = allCountries[index];
                        String displayName = (isAr && _arabicCountryNames.containsKey(c.code)) 
                            ? _arabicCountryNames[c.code]! 
                            : c.name;
                        return ListTile(
                          leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                          title: Text(displayName),
                          trailing: Text(isAr ? _localizeDigits("+${c.dialCode}") : "+${c.dialCode}"),
                          onTap: () {
                            setState(() {
                              currentCountryCode = "+${c.dialCode}";
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = context.locale.languageCode == 'ar';
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgBlueLight, AppColors.bgPurpleLight, Colors.white],
            stops: const [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  const AppLogoHeader(),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
                      ],
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              if (widget.onBackPressed != null) {
                                Navigator.pop(context);
                                widget.onBackPressed!();
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(
                              Icons.arrow_back, 
                              color: Colors.black, 
                              size: 28
                            ),
                          ),
                        ),
                    
                        _buildGradientTitle(),
                        const SizedBox(height: 25),
                        Row(
                          children: [
                            Expanded(child: CustomTextField(label: "first_name".tr(), hintText: "first_name_hint".tr(), controller: firstNameController)),
                            const SizedBox(width: 15),
                            Expanded(child: CustomTextField(label: "last_name".tr(), hintText: "last_name_hint".tr(), controller: lastNameController)),
                          ],
                        ),
                        CustomTextField(label: "relationship".tr(), hintText: "relationship_hint".tr(), controller: relationController),
                        const SizedBox(height: 10),
                        Align(
                          alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                          child: Text("phone_number".tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))
                        ),
                        const SizedBox(height: 8),
                        
                        // Custom Phone Field
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _showCountryPicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                                  child: Row(
                                    children: [
                                      Text(countries.firstWhere((c) => "+${c.dialCode}" == currentCountryCode).flag, style: const TextStyle(fontSize: 20)),
                                      const SizedBox(width: 5),
                                      Text(isArabic ? _localizeDigits(currentCountryCode) : currentCountryCode, style: const TextStyle(fontSize: 16)),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.phone,
                                  onChanged: (val) => fullPhoneNumber = currentCountryCode + val,
                                  inputFormatters: isArabic ? [ArabicDigitsFormatter()] : [],
                                  decoration: InputDecoration(
                                    hintText: isArabic ? '١٥٥١٤٧١٧٤٧' : '1551471747',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                        CustomButton(text: "save".tr(), onPressed: _saveContact),
                        const SizedBox(height: 12),
                        _buildImagePickerButton(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientTitle() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(colors: AppColors.logoGradient).createShader(bounds),
      child: Text("add_contact_title".tr(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildImagePickerButton() {
    return SizedBox(
      width: double.infinity,
      height: _selectedImage == null ? 48 : 120,
      child: OutlinedButton(
        onPressed: _pickImage,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF4983F6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _selectedImage == null
          ? Text("add_picture".tr(), style: const TextStyle(color: Colors.black))
          : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity)),
      ),
    );
  }
}