import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl_phone_field/countries.dart';
import '../../config/api_config.dart';
import '../../config/colors.dart';
import '../../custom_widgets/custom_button.dart';
import '../../custom_widgets/custom_text_field.dart';
import '../../custom_widgets/logo_header.dart';

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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String phoneNumber = "";
  String currentCountryCode = "+20";
  bool isLoading = false;

  final Map<String, String> _arabicCountryNames = {
    "AF": "أفغانستان", "AX": "جزر أولاند", "AL": "ألبانيا", "DZ": "الجزائر", "AS": "ساموا الأمريكية", "AD": "أندورا", "AO": "أنغولا", "AI": "أنغويلا", "AQ": "أنتاركتيكا", "AG": "أنتيغوا وبربودا", "AR": "الأرجنتين", "AM": "أرمينيا", "AW": "أروبا", "AU": "أستراليا", "AT": "النمسا", "AZ": "أذربيجان", "BS": "جزر البهاما", "BH": "البحرين", "BD": "بنجلاديش", "BB": "باربادوس", "BY": "بيلاروسيا", "BE": "بلجيكا", "BZ": "بليز", "BJ": "بنين", "BM": "برمودا", "BT": "بوتان", "BO": "بوليفيا", "BA": "البوسنة والهرسك", "BW": "بوتسوانا", "BV": "جزيرة بوفيه", "BR": "البرازيل", "IO": "إقليم المحيط الهندي البريطاني", "BN": "بروناي", "BG": "بلغاريا", "BF": "بوركينا فاسو", "BI": "بوروندي", "KH": "كمبوديا", "CM": "الكاميرون", "CA": "كندا", "CV": "الرأس الأخضر", "KY": "جزر كايمان", "CF": "جمهورية أفريقيا الوسطى", "TD": "تشاد", "CL": "تشيلي", "CN": "الصين", "CX": "جزيرة الكريسماس", "CC": "جزر كوكوس", "CO": "كولومبيا", "KM": "جزر القمر", "CG": "الكونغو", "CD": "الكونغو الديمقراطية", "CK": "جزر كوك", "CR": "كوستاريكا", "CI": "ساحل العاج", "HR": "كرواتيا", "CU": "كوبا", "CY": "قبرص", "CZ": "جمهورية التشيك", "DK": "الدنمارك", "DJ": "جيبوتي", "DM": "دومينيكا", "DO": "جمهورية الدومينيكان", "EC": "الإكوادور", "EG": "مصر", "SV": "السلفادور", "GQ": "غينيا الاستوائية", "ER": "إريتريا", "EE": "إستونيا", "ET": "إثيوبيا", "FK": "جزر فوكلاند", "FO": "جزر فارو", "FJ": "فيجي", "FI": "فنلندا", "FR": "فرنسا", "GF": "غويانا الفرنسية", "PF": "بولينيزيا الفرنسية", "TF": "الأقاليم الجنوبية الفرنسية", "GA": "الغابون", "GM": "غامبيا", "GE": "جورجيا", "DE": "ألمانيا", "GH": "غانا", "GI": "جبل طارق", "GR": "اليونان", "GL": "جرينلاند", "GD": "غرينادا", "GP": "غوادلوب", "GU": "غوام", "GT": "غواتيمالا", "GG": "غيرنزي", "GN": "غينيا", "GW": "غينيا بيساو", "GY": "غويانا", "HT": "هايتي", "HM": "جزيرة هيرد وجزر ماكدونالد", "VA": "الفاتيكان", "HN": "هندوراس", "HK": "هونج كونج", "HU": "المجر", "IS": "آيسلندا", "IN": "الهند", "ID": "إندونيسيا", "IR": "إيران", "IQ": "العراق", "IE": "أيرلندا", "IM": "جزيرة مان", "IL": "إسرائيل", "IT": "إيطاليا", "JM": "جامايكا", "JP": "اليابان", "JE": "جيرزي", "JO": "الأردن", "KZ": "كازاخستان", "KE": "كينيا", "KI": "كيريباتي", "KP": "كوريا الشمالية", "KR": "كوريا الجنوبية", "KW": "الكويت", "KG": "قيرغيزستان", "LA": "لاوس", "LV": "لاتفيا", "LB": "لبنان", "LS": "ليسوتو", "LR": "ليبيريا", "LY": "ليبيا", "LI": "ليختنشتاين", "LT": "ليتوانيا", "LU": "لوكسمبورغ", "MO": "ماكاو", "MK": "مقدونيا", "MG": "مدغشقر", "MW": "ملاوي", "MY": "ماليزيا", "MV": "جزر المالديف", "ML": "مالي", "MT": "مالطا", "MH": "جزر مارشال", "MQ": "مارتينيك", "MR": "موريتانيا", "MU": "موريشيوس", "YT": "مايوت", "MX": "المكسيك", "FM": "ميكرونيزيا", "MD": "مولدوفا", "MC": "موناكو", "MN": "منغوليا", "ME": "الجبل الأسود", "MS": "مونتسرات", "MA": "المغرب", "MZ": "موزمبيق", "MM": "ميانمار", "NA": "ناميبيا", "NR": "ناورو", "NP": "نيبال", "NL": "هولندا", "AN": "جزر الأنتيل الهولندية", "NC": "كاليدونيا الجديدة", "NZ": "نيوزيلندا", "NI": "نيكاراغوا", "NE": "النيجر", "NG": "نيجيريا", "NU": "نييوي", "NF": "جزيرة نورفولك", "MP": "جزر ماريانا الشمالية", "NO": "النرويج", "OM": "عمان", "PK": "باكستان", "PW": "بالاو", "PS": "فلسطين", "PA": "بنما", "PG": "بابوا غينيا الجديدة", "PY": "باراغواي", "PE": "بيرو", "PH": "الفلبين", "PN": "بيتكيرن", "PL": "بولندا", "PT": "البرتغال", "PR": "بورتوريكو", "QA": "قطر", "RE": "ريونيون", "RO": "رومانيا", "RU": "روسيا", "RW": "رواندا", "BL": "سان بارتليمي", "SH": "سانت هيلانة", "KN": "سانت كيتس ونيفيس", "LC": "سانت لوسيا", "MF": "سانت مارتن", "PM": "سان بيير وميكلون", "VC": "سانت فينسنت والغرينادين", "WS": "ساموا", "SM": "سان مارينو", "ST": "ساو تومي وبرينسيب", "SA": "السعودية", "SN": "السنغال", "RS": "صربيا", "SC": "سيشل", "SL": "سيراليون", "SG": "سنغافورة", "SK": "سلوفاكيا", "SI": "سلوفينيا", "SB": "جزر سليمان", "SO": "الصومال", "ZA": "جنوب أفريقيا", "GS": "جورجيا الجنوبية وجزر ساندويتش الجنوبية", "ES": "إسبانيا", "LK": "سريلانكا", "SD": "السودان", "SR": "سورينام", "SJ": "سفالبارد ويان ماين", "SZ": "سوازيلاند", "SE": "السويد", "CH": "سويسرا", "SY": "سوريا", "TW": "تايوان", "TJ": "طاجيكستان", "TZ": "تنزانيا", "TH": "تايلاند", "TL": "تيمور الشرقية", "TG": "توغو", "TK": "توكيلو", "TO": "تونغا", "TT": "ترينيداد وتوباغو", "TN": "تونس", "TR": "تركيا", "TM": "تركمانستان", "TC": "جزر تركس وكايكوس", "TV": "توفالو", "UG": "أوغندا", "UA": "أوكرانيا", "AE": "الإمارات العربية المتحدة", "GB": "المملكة المتحدة", "US": "الولايات المتحدة", "UM": "جزر الولايات المتحدة الصغيرة النائية", "UY": "أوروغواي", "UZ": "أوزبكستان", "VU": "فانواتو", "VE": "فنزويلا", "VN": "فيتنام", "VG": "جزر فيرجن البريطانية", "VI": "جزر فيرجن الأمريكية", "WF": "واليس وفوتونا", "EH": "الصحراء الغربية", "YE": "اليمن", "ZM": "زامبيا", "ZW": "زيمبابوي"
  };

  String _localizeDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

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

  void showSnackBar(String message, {bool isError = true, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  void _showChangeIpDialog(BuildContext context) {
    final TextEditingController ipController = TextEditingController(text: ApiConfig.serverIp);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير عنوان السيرفر (Server IP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل عنوان الـ IP الخاص بجهاز الـ Mac حالياً:'),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                hintText: 'مثال: 192.168.1.29',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              String newIp = ipController.text.trim();
              if (newIp.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('custom_server_ip', newIp);
                ApiConfig.setServerIp(newIp);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم تحديث الـ IP إلى: $newIp. يرجى المحاولة مجدداً.')),
                  );
                }
              }
            },
            child: const Text('حفظ وتحديث'),
          ),
        ],
      ),
    );
  }

  Future<void> registerUser({bool isRetry = false}) async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || phoneNumber.isEmpty || password.isEmpty) {
      showSnackBar("please_fill_fields".tr());
      return;
    }

    String phoneToSend = phoneNumber;
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabic.length; i++) {
      phoneToSend = phoneToSend.replaceAll(arabic[i], english[i]);
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      showSnackBar("valid_email_error".tr());
      return;
    }

    if (password.length < 8) {
      showSnackBar("password_min_length".tr());
      return;
    }

    if (password != confirmPassword) {
      showSnackBar("passwords_not_match".tr());
      return;
    }

    setState(() => isLoading = true);

    print("DEBUG: Registering user with: $email, $phoneToSend");

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "first_name": firstName,
          "last_name": lastName,
          "email": email,
          "phone_number": phoneToSend,
          "password": password,
          "password_confirmation": confirmPassword
        }),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 422) {
        debugPrint('[Signup] Server validation error: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${data['message'] ?? data['errors'] ?? response.body}')),
        );
        setState(() => isLoading = false);
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        if (data['token'] != null) {
          await prefs.setString('token', data['token']);
        }
        if (data['user'] != null) {
          if (data['user']['id'] != null) {
            await prefs.setString('user_id', data['user']['id'].toString());
          }
          if (data['user']['first_name'] != null) {
            await prefs.setString('first_name', data['user']['first_name']);
          }
          if (data['user']['last_name'] != null) {
            await prefs.setString('last_name', data['user']['last_name']);
          }
        }
        
        showSnackBar("account_created".tr(), isError: false);
        Navigator.pushNamed(context, '/confirmed');
      } 
      else if (response.statusCode == 422) {
        String errorMessage = "Registration failed";
        if (data["errors"] != null) {
          var firstError = data["errors"].values.first;
          errorMessage = firstError is List ? firstError.first : firstError.toString();
        }
        showSnackBar(errorMessage);
      } 
      else {
        showSnackBar(data["message"] ?? "Something went wrong");
      }
    } catch (e) {
      print("DEBUG: Signup Error: $e");
      
      if (!isRetry) {
        // Show a temporary dialog while we search the network for the server
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري البحث التلقائي عن السيرفر في الشبكة...'),
                  ],
                ),
              ),
            ),
          ),
        );
        
        String? foundIp = await ApiConfig.autoDiscoverServer();
        if (context.mounted) Navigator.pop(context);
        
        if (foundIp != null) {
          // Retry registration with the newly found IP address
          await registerUser(isRetry: true);
          return;
        }
      }

      showSnackBar(
        "connection_error".tr(),
        action: SnackBarAction(
          label: 'تحديث الـ IP',
          textColor: Colors.white,
          onPressed: () => _showChangeIpDialog(context),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isArabic = context.locale.languageCode == 'ar';
    return Scaffold(
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
          child: Column(
            children: [
              const AppLogoHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Container(
                      width: 343,
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                            child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: AppColors.logoGradient,
                            ).createShader(bounds),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                "sign_up".tr(),
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("${"already_have_account".tr()} ", style: const TextStyle(fontSize: 13)),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/login'),
                                child: Text(
                                  "login_small".tr(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: firstNameController,
                                  label: "first_name".tr(),
                                  hintText: "first_name_hint".tr(),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: CustomTextField(
                                  controller: lastNameController,
                                  label: "last_name".tr(),
                                  hintText: "last_name_hint".tr(),
                                ),
                              ),
                            ],
                          ),
                          CustomTextField(
                            controller: emailController,
                            label: "email".tr(),
                            hintText: "enter_email".tr(),
                          ),
                          Align(
                            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                            child: Text("phone_number".tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
                                        Text(
                                          countries.any((c) => "+${c.dialCode}" == currentCountryCode)
                                            ? countries.firstWhere((c) => "+${c.dialCode}" == currentCountryCode).flag
                                            : "🇪🇬", 
                                          style: const TextStyle(fontSize: 20)
                                        ),
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
                                    onChanged: (val) => phoneNumber = currentCountryCode + val,
                                    inputFormatters: isArabic ? [ArabicDigitsFormatter()] : [],
                                    decoration: InputDecoration(
                                      hintText: 'Enter your number'.tr(),
                                      hintStyle: TextStyle(color: Colors.grey.shade400),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          CustomTextField(
                            controller: passwordController,
                            label: "set_password".tr(),
                            isPassword: true,
                          ),
                          CustomTextField(
                            controller: confirmPasswordController,
                            label: "confirm_password".tr(),
                            isPassword: true,
                          ),
                          const SizedBox(height: 30),
                          isLoading
                              ? const CircularProgressIndicator()
                              : CustomButton(
                                  text: "register".tr(),
                                  onPressed: registerUser,
                                ),
                        ],
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
}