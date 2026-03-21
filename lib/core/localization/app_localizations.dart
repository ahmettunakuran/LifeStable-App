import 'package:flutter/material.dart';

final localeNotifier = ValueNotifier<Locale>(const Locale('en'));

class S {
  static final Map<String, Map<String, String>> _data = {
    'en': {
      'welcome_back': 'Welcome\nback.',
      'sign_in_subtitle': 'Sign in to continue your journey.',
      'email': 'Email',
      'password': 'Password',
      'forgot_password': 'Forgot password?',
      'sign_in': 'Sign In',
      'or_continue_with': 'or continue with',
      'continue_with_google': 'Continue with Google',
      'no_account': "Don't have an account? ",
      'create_one': 'Create one',
      'create_account_title': 'Create\naccount.',
      'create_account_subtitle': 'Start building a stable life today.',
      'full_name': 'Full Name',
      'confirm_password': 'Confirm Password',
      'create_account_btn': 'Create Account',
      'already_have_account': 'Already have an account? ',
      'sign_in_link': 'Sign in',
      'forgot_password_title': 'Forgot\npassword?',
      'forgot_password_subtitle': "No worries, we'll send you reset instructions.",
      'send_reset_link': 'Send Reset Link',
      'back_to_sign_in': 'Back to Sign In',
      'check_email_title': 'Check your\nemail.',
      'check_email_subtitle': "We've sent a password reset link to your email.",
      'email_required': 'Email and password are required.',
      'passwords_no_match': 'Passwords do not match.',
      'fill_all_fields': 'Please fill all required fields.',
      'name_hint': 'John Doe',
      'email_hint': 'you@example.com',
    },
    'tr': {
      'welcome_back': 'Tekrar\nhoş geldin.',
      'sign_in_subtitle': 'Yolculuğuna devam et.',
      'email': 'E-posta',
      'password': 'Şifre',
      'forgot_password': 'Şifremi unuttum?',
      'sign_in': 'Giriş Yap',
      'or_continue_with': 'veya şununla devam et',
      'continue_with_google': 'Google ile Devam Et',
      'no_account': 'Hesabın yok mu? ',
      'create_one': 'Oluştur',
      'create_account_title': 'Hesap\noluştur.',
      'create_account_subtitle': 'Dengeli bir hayat kurmaya başla.',
      'full_name': 'Ad Soyad',
      'confirm_password': 'Şifreyi Onayla',
      'create_account_btn': 'Hesap Oluştur',
      'already_have_account': 'Zaten hesabın var mı? ',
      'sign_in_link': 'Giriş yap',
      'forgot_password_title': 'Şifreni mi\nunuttun?',
      'forgot_password_subtitle': 'Endişelenme, sıfırlama talimatları göndereceğiz.',
      'send_reset_link': 'Sıfırlama Bağlantısı Gönder',
      'back_to_sign_in': 'Girişe Dön',
      'check_email_title': 'E-postanı\nkontrol et.',
      'check_email_subtitle': 'Şifre sıfırlama bağlantısı e-posta adresine gönderildi.',
      'email_required': 'E-posta ve şifre gereklidir.',
      'passwords_no_match': 'Şifreler eşleşmiyor.',
      'fill_all_fields': 'Lütfen tüm alanları doldurun.',
      'name_hint': 'Ad Soyad',
      'email_hint': 'siz@ornek.com',
    },
  };

  static String of(String key) {
    final lang = localeNotifier.value.languageCode;
    return _data[lang]?[key] ?? _data['en']?[key] ?? key;
  }
}

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black.withOpacity(0.3),
            border: Border.all(color: AppColors.gold.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LangButton(label: 'EN', locale: const Locale('en'), current: locale),
              _LangButton(label: 'TR', locale: const Locale('tr'), current: locale),
            ],
          ),
        );
      },
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final Locale locale;
  final Locale current;

  const _LangButton({
    required this.label,
    required this.locale,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current.languageCode == locale.languageCode;
    return GestureDetector(
      onTap: () => localeNotifier.value = locale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
            colors: [AppColors.gold, AppColors.goldDark],
          )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class AppColors {
  static const Color gold = Color(0xFFC9A84C);
  static const Color goldDark = Color(0xFF9A7B2F);
  static const Color goldLight = Color(0xFFF5C842);
  static const Color black = Color(0xFF0D0D0D);
  static const Color darkBg = Color(0xFF141008);
  static const Color darkBg2 = Color(0xFF1E1608);
  static const Color cardBg = Color(0xFF1A1500);
}