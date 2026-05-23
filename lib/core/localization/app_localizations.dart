import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeNotifier = ValueNotifier<Locale>(const Locale('en'));

class S {
  static const String _localeKey = 'app_locale';

  static Future<void> loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey) ?? 'en';
    localeNotifier.value = Locale(code);
  }

  static Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    localeNotifier.value = locale;
  }

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
      // Onboarding
      'get_started': 'Get Started',
      'onboarding_subtitle': 'Build habits.\nLive intentionally.',
      'already_have_account_onboarding': 'Already have an account? Sign in',
      'check_email_title': 'Check your\nemail.',
      'check_email_subtitle': "We've sent a password reset link to your email.",
      'email_required': 'Email and password are required.',
      'passwords_no_match': 'Passwords do not match.',
      'fill_all_fields': 'Please fill all required fields.',
      'email_required_field': 'Email is required.',
      'email_invalid': 'Please enter a valid email address.',
      'password_required_field': 'Password is required.',
      'password_min_length': 'Password must be at least 6 characters.',
      'password_max_length': 'Password is too long (max 64 characters).',
      'password_needs_letter_number':
          'Password must contain at least one letter and one number.',
      'password_no_whitespace':
          'Password cannot start or end with a space.',
      'password_requirements_hint':
          'At least 6 characters, with a letter and a number.',
      'name_required': 'Name is required.',
      'name_min_length': 'Name must be at least 2 characters.',
      'name_hint': 'John Doe',
      'email_hint': 'you@example.com',
      // Dashboard & Menu
      'calendar': 'Calendar',
      'tasks': 'To-Do List',
      'team': 'Team',
      'ai_bot': 'AI Bot',
      'habits': 'Habits',
      'settings': 'Settings',
      'dashboard': 'Dashboard',
      'add_location': 'Add Location',
      'app_assistant': 'App Assistant',
      'logout': 'Log Out',
      'fast_summary': 'Fast Summary',
      'summary_tasks': 'Tasks',
      'summary_habits': 'Habits',
      'summary_events': 'Events',
      'summary_done': 'done',
      'summary_today': 'today',
      'todays_brief': "Today's Brief",
      'greeting_hey': 'Hey',
      'due_today_short': 'Due Today',
      'domains_title': 'Domains',
      'new_short': 'New',
      'no_summary': 'No summary available.',
      'show_more': 'Show more',
      'show_less': 'Show less',
      'todays_schedule': "Today's Schedule",
      'todays_focus': "Today's Focus",
      'close_deadlines': 'Close Deadlines',
      'recommendations_ai': 'RECOMMENDATIONS (AI)',
      'streak_tracker': 'Streak Tracker',
      'no_habits_yet': 'No habits yet.',
      'active': 'active',
      'days': 'days',
      'deadlines_today': 'You Have {} Deadlines Today.',
      // Calendar
      'month_week': 'Month / Week',
      'day_view': 'Day View',
      'new_event': 'New Event',
      'no_events_today': 'No events today',
      'import_schedule': 'Import Course Schedule',
      'confirm_schedule': 'Confirm Schedule',
      'number_of_weeks': 'Repeat for weeks:',
      // Settings
      'language': 'Language',
      'calendar_sync': 'Calendar Sync',
      'connected': 'Connected',
      'not_connected': 'Not connected',
      'sync_now': 'Sync now',
      'disconnect': 'Disconnect',
      'connect': 'Connect',
      'english': 'English',
      'turkish': 'Turkish',
      // Subscription / Plans
      'subscription': 'Subscription',
      'current_plan': 'Current plan',
      'view_plans': 'View Plans',
      'manage_plan': 'Manage plan',
      'usage_this_month': 'Usage this month',
      'usage_remaining': '{used} of {limit} used',
      'usage_unlimited': 'Unlimited',
      'usage_exhausted': 'Limit reached',
      'usage_near_limit_warning':
          "You're close to your monthly limit. Upgrade to keep going.",
      'feature_ocr': 'Schedule OCR',
      'feature_ai_assistant': 'AI Assistant',
      'feature_voice': 'Voice transcription',
      'feature_help_bot': 'Help Bot',
      'quota_reached_title': 'Monthly limit reached',
      'quota_reached_ocr':
          "You've used all {limit} schedule imports this month on the Free plan. Upgrade to Plus or Pro for more.",
      'quota_reached_generic':
          "You've reached this month's limit for {feature}. Upgrade to keep using it.",
      'see_plans': 'See plans',
      'maybe_later': 'Maybe later',
      'premium_plans_title': 'LifeStable Plans',
      'premium_plans_subtitle':
          'Pick the plan that matches how much you rely on LifeStable.',
      'plan_free_title': 'Free',
      'plan_plus_title': 'Plus',
      'plan_pro_title': 'Pro',
      'plan_free_tag': 'Start here, no card needed.',
      'plan_plus_tag': 'For students who use AI every day.',
      'plan_pro_tag': 'Unlimited everything, for power users.',
      'per_month': '/month',
      'per_year': '/year',
      'save_yearly': 'Save with yearly',
      'current_plan_badge': 'Current plan',
      'coming_soon': 'Coming soon',
      'plan_cta_active': "You're on this plan",
      'plan_cta_upgrade': 'Upgrade',
      'plan_cta_unavailable': 'Not yet available',
      // Plan feature bullets — Free
      'plan_feature_free_ocr': '3 schedule OCR imports per month',
      'plan_feature_free_ai': '50 AI assistant prompts per month',
      'plan_feature_free_voice': '5 voice transcriptions per month',
      'plan_feature_free_helpbot': '30 help-bot questions per month',
      'plan_feature_free_calendar': 'Google Calendar sync',
      // Plus
      'plan_feature_plus_ocr': '30 schedule OCR imports per month',
      'plan_feature_plus_ai': '500 AI assistant prompts per month',
      'plan_feature_plus_voice': '100 voice transcriptions per month',
      'plan_feature_plus_helpbot': 'Unlimited help-bot questions',
      'plan_feature_plus_insights': 'Advanced dashboard insights',
      'plan_feature_plus_support': 'Priority email support',
      // Pro
      'plan_feature_pro_unlimited': 'Unlimited everything',
      'plan_feature_pro_team': 'Larger team workspaces',
      'plan_feature_pro_priority': 'Priority API queue',
      'plan_feature_pro_early': 'Early access to new features',
      'plan_feature_pro_support': '24/7 chat support',
      'billing_disclaimer':
          'Paid plans are not yet available. Prices shown are indicative and may change at launch.',
      // Common
      'cancel': 'Cancel',
      'delete': 'Delete',
      'save': 'Save',
      'close': 'Close',
      'free_plan': 'Free plan',
      'edit_name': 'Edit name',
      'ok': 'OK',
      // Settings
      'calendar_sync_description':
          'Connect your Google Calendar to import events into LifeStable.',
      'disconnect_google_title': 'Disconnect Google Calendar',
      'disconnect_google_body':
          'This removes the Google connection and sync mappings. Imported events already in LifeStable will stay unless you delete them manually.',
      'browser_opened_msg':
          'Browser opened. Return here after approving access.',
      'could_not_open_msg': 'Could not open the Google sign-in page.',
      'connect_failed': 'Connect failed',
      'sync_failed': 'Sync failed',
      'sync_complete_msg':
          'Sync complete  •  Created: {c}  Updated: {u}  Deleted: {d}',
      'google_disconnected': 'Google Calendar disconnected.',
      'disconnect_failed': 'Disconnect failed',
      'no_google_account_msg':
          'No Google account connected. Tap Connect to import your events.',
      'account_label': 'Account',
      'last_sync_label': 'Last sync',
      'language_section': 'Language',
      'language_section_description':
          'Choose the language used across the app.',
      // Calendar
      'choose_from_gallery': 'Choose from Gallery',
      'take_a_photo': 'Take a Photo',
      'no_courses_found': 'No courses found in image.',
      'courses_added_count': '{n} courses added to calendar!',
      'generic_error': 'Error',
      'add_to_calendar': 'Add to Calendar',
      'linked_task': 'Linked task',
      'delete_event_q': 'Delete event?',
      'event_type_personal': 'Personal',
      'event_type_task': 'Task',
      'event_type_class': 'Class',
      'event_type_team': 'Team',
      // Home dashboard
      'all_clear_today': 'All clear today!',
      'you_have_tasks_today': 'You have {n} task(s) today.',
      'next_up': 'Next up:',
      'all_clear': 'All clear!',
      'no_domains_yet': 'No domains yet',
      // Tasks
      'no_tasks_found': 'No tasks found.',
      'ai_magic_task': 'AI Magic Task',
      'ai_thinking': 'AI is thinking...',
      'ai_task_created': 'Task created by AI! ✨',
      'ai_event_created': 'Calendar event created by AI! 📅',
      'ai_event_failed': 'Failed to create event',
      'ai_could_not_understand':
          'AI could not understand or created an event.',
      'magic_btn': 'Magic!',
      'board_title': 'BOARD',
      'col_todo': 'TO DO',
      'col_doing': 'DOING',
      'col_done': 'DONE',
      'add_task': 'Add Task',
      'ai_prompt_hint': 'e.g. Add a grocery run tomorrow at 8pm',
      'nav_team': 'Team',
      'nav_calendar': 'Calendar',
      'nav_dashboard': 'Dashboard',
      'nav_habit': 'Habit',
      // Event create/edit
      'new_event_title': 'NEW EVENT',
      'edit_event_title': 'EDIT EVENT',
      'event_title_hint': 'Event title',
      'event_description_hint': 'Description (optional)',
      'event_section_type': 'Event Type',
      'event_section_time': 'Time',
      'event_section_team': 'Team',
      'event_section_assign_members': 'Assign Members',
      'event_section_link_task': 'Link to Task (optional)',
      'time_start': 'Start',
      'time_end': 'End',
      'title_required': 'Title is required',
      'end_after_start': 'End time must be after start time',
      'conflicts_label_one': 'Conflicts with {n} event: {titles}',
      'conflicts_label_many': 'Conflicts with {n} events: {titles}',
      'loading_teams': 'Loading your teams…',
      'no_teams_hint':
          'You are not in any team yet. Create or join one from the Teams screen.',
      'select_a_team': 'Select a team',
      'no_team_option': '— No team —',
      'members_suffix': 'members',
      'tap_toggle_assignment': 'Tap to toggle assignment',
      'no_members_assigned_warning':
          '⚠ No members assigned — at least one is required',
      'loading_tasks': 'Loading tasks…',
      'no_pending_tasks_hint':
          'No pending tasks found. Add tasks from the Domains screen.',
      'select_task_to_link': 'Select a task to link',
      'no_linked_task_option': '— No linked task —',
      'delete_event_btn': 'Delete Event',
      'delete_event_undone': 'This action cannot be undone.',
      'save_changes': 'Save Changes',
      'create_event': 'Create Event',
      'select_team_required': 'Please select a team for this event',
      'assign_member_required': 'Please assign at least one member',
      'time_conflict_title': 'Time Conflict',
      'time_conflict_body': 'This event overlaps with: {titles}. Save anyway?',
      'save_anyway': 'Save Anyway',
      'save_failed': 'Failed to save',
      // Domain edit
      'new_domain': 'New Domain',
      'edit_domain': 'Edit Domain',
      'delete_domain': 'Delete Domain',
      'delete_domain_confirm': 'This domain will be deleted. Its tasks will not be removed.',
      'new_domain_subtitle': 'Create a new life domain to organize your tasks.',
      'domain_name': 'Domain Name',
      'domain_name_hint': 'e.g., School, Health, Work',
      'description_optional_label': 'Description (Optional)',
      'domain_description_hint': 'What is this domain about?',
      'icon_label': 'Icon',
      'color_label': 'Color',
      'create_domain': 'Create Domain',
      'required_field': 'Required',
      // Teams
      'team_dashboard_title': 'Team Dashboard',
      'no_teams_yet': 'No teams yet.',
      'no_teams_hint_dashboard': 'Create one or join with a code.',
      'create_team': 'Create Team',
      'create_btn': 'Create',
      'team_name': 'Team Name',
      'objective_optional': 'Objective (optional)',
      'team_color': 'Team Color',
      'join_with_code': 'Join with Code',
      'team_created_title': 'Team Created!',
      'share_invite_code': 'Share this invite code with your teammates:',
      'invite_code_copied': 'Invite code copied!',
      'tap_to_copy': 'Tap to copy',
      'error_label': 'Error',
      // Calendar count chip
      'event_count_one': '{n} event',
      'event_count_many': '{n} events',
      'team_count': '{n} team',
      'conflict_count': '{n} conflict',
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
      // Onboarding
      'get_started': 'Hadi Başlayalım',
      'onboarding_subtitle': 'Alışkanlıklar edin.\nBilinçli yaşa.',
      'already_have_account_onboarding': 'Zaten hesabın var mı? Giriş yap',
      'check_email_title': 'E-postanı\nkontrol et.',
      'check_email_subtitle': 'Şifre sıfırlama bağlantısı e-posta adresine gönderildi.',
      'email_required': 'E-posta ve şifre gereklidir.',
      'passwords_no_match': 'Şifreler eşleşmiyor.',
      'fill_all_fields': 'Lütfen tüm alanları doldurun.',
      'email_required_field': 'E-posta gerekli.',
      'email_invalid': 'Geçerli bir e-posta adresi girin.',
      'password_required_field': 'Şifre gerekli.',
      'password_min_length': 'Şifre en az 6 karakter olmalı.',
      'password_max_length': 'Şifre çok uzun (en fazla 64 karakter).',
      'password_needs_letter_number':
          'Şifre en az bir harf ve bir rakam içermelidir.',
      'password_no_whitespace':
          'Şifre boşlukla başlayamaz veya bitemez.',
      'password_requirements_hint':
          'En az 6 karakter, bir harf ve bir rakam içermeli.',
      'name_required': 'Ad gerekli.',
      'name_min_length': 'Ad en az 2 karakter olmalı.',
      'name_hint': 'Ad Soyad',
      'email_hint': 'siz@ornek.com',
      // Dashboard & Menu
      'calendar': 'Takvim',
      'tasks': 'Yapılacaklar',
      'team': 'Takım',
      'ai_bot': 'AI Bot',
      'habits': 'Alışkanlıklar',
      'settings': 'Ayarlar',
      'dashboard': 'Panel',
      'add_location': 'Konum Ekle',
      'app_assistant': 'Uygulama Asistanı',
      'logout': 'Çıkış Yap',
      'fast_summary': 'Hızlı Özet',
      'summary_tasks': 'Görevler',
      'summary_habits': 'Alışkanlıklar',
      'summary_events': 'Etkinlikler',
      'summary_done': 'tamam',
      'summary_today': 'bugün',
      'todays_brief': 'Günün Özeti',
      'greeting_hey': 'Selam',
      'due_today_short': 'Bugün',
      'domains_title': 'Alanlar',
      'new_short': 'Yeni',
      'no_summary': 'Özet bulunamadı.',
      'show_more': 'Daha fazla',
      'show_less': 'Daha az',
      'todays_schedule': 'Bugünkü Program',
      'todays_focus': 'Bugünün Odağı',
      'close_deadlines': 'Yaklaşan Teslimler',
      'recommendations_ai': 'ÖNERİLER (AI)',
      'streak_tracker': 'Seri Takibi',
      'no_habits_yet': 'Henüz alışkanlık yok.',
      'active': 'aktif',
      'days': 'gün',
      'deadlines_today': 'Bugün {} Teslimin Var.',
      // Calendar
      'month_week': 'Ay / Hafta',
      'day_view': 'Gün Görünümü',
      'new_event': 'Yeni Etkinlik',
      'no_events_today': 'Bugün etkinlik yok',
      'import_schedule': 'Ders Programı İçe Aktar',
      'confirm_schedule': 'Programı Onayla',
      'number_of_weeks': 'Kaç hafta eklensin?',
      // Settings
      'language': 'Dil',
      'calendar_sync': 'Takvim Senkronizasyonu',
      'connected': 'Bağlı',
      'not_connected': 'Bağlı değil',
      'sync_now': 'Senkronize Et',
      'disconnect': 'Bağlantıyı Kes',
      'connect': 'Bağlan',
      'english': 'İngilizce',
      'turkish': 'Türkçe',
      // Subscription / Plans
      'subscription': 'Abonelik',
      'current_plan': 'Mevcut plan',
      'view_plans': 'Planları Gör',
      'manage_plan': 'Planı yönet',
      'usage_this_month': 'Bu ayki kullanım',
      'usage_remaining': '{limit} kullanımdan {used} kullanıldı',
      'usage_unlimited': 'Sınırsız',
      'usage_exhausted': 'Limit doldu',
      'usage_near_limit_warning':
          'Aylık limitine yaklaştın. Devam etmek için planını yükselt.',
      'feature_ocr': 'Program OCR',
      'feature_ai_assistant': 'AI Asistan',
      'feature_voice': 'Sesli yazıya çevirme',
      'feature_help_bot': 'Yardım Botu',
      'quota_reached_title': 'Aylık limit doldu',
      'quota_reached_ocr':
          'Bu ay Free planındaki {limit} program içe aktarımının tamamını kullandın. Daha fazlası için Plus veya Pro paketine geç.',
      'quota_reached_generic':
          'Bu ay {feature} özelliği için limitin doldu. Devam etmek için planını yükselt.',
      'see_plans': 'Planları Gör',
      'maybe_later': 'Daha sonra',
      'premium_plans_title': 'LifeStable Planları',
      'premium_plans_subtitle':
          'LifeStable\'ı ne kadar kullandığına uygun planı seç.',
      'plan_free_title': 'Free',
      'plan_plus_title': 'Plus',
      'plan_pro_title': 'Pro',
      'plan_free_tag': 'Buradan başla, kart gerekmez.',
      'plan_plus_tag': 'Her gün AI kullanan öğrenciler için.',
      'plan_pro_tag': 'İleri kullanıcılar için sınırsız her şey.',
      'per_month': '/ay',
      'per_year': '/yıl',
      'save_yearly': 'Yıllık ödemede kazan',
      'current_plan_badge': 'Mevcut plan',
      'coming_soon': 'Yakında',
      'plan_cta_active': 'Bu plandasın',
      'plan_cta_upgrade': 'Yükselt',
      'plan_cta_unavailable': 'Henüz aktif değil',
      // Plan özellikleri — Free
      'plan_feature_free_ocr': 'Ayda 3 program OCR içe aktarımı',
      'plan_feature_free_ai': 'Ayda 50 AI asistan komutu',
      'plan_feature_free_voice': 'Ayda 5 sesli yazıya çevirme',
      'plan_feature_free_helpbot': 'Ayda 30 yardım botu sorusu',
      'plan_feature_free_calendar': 'Google Takvim senkronizasyonu',
      // Plus
      'plan_feature_plus_ocr': 'Ayda 30 program OCR içe aktarımı',
      'plan_feature_plus_ai': 'Ayda 500 AI asistan komutu',
      'plan_feature_plus_voice': 'Ayda 100 sesli yazıya çevirme',
      'plan_feature_plus_helpbot': 'Sınırsız yardım botu sorusu',
      'plan_feature_plus_insights': 'Gelişmiş panel öngörüleri',
      'plan_feature_plus_support': 'Öncelikli e-posta desteği',
      // Pro
      'plan_feature_pro_unlimited': 'Her şey sınırsız',
      'plan_feature_pro_team': 'Daha büyük takım çalışma alanları',
      'plan_feature_pro_priority': 'Öncelikli API sırası',
      'plan_feature_pro_early': 'Yeni özelliklere erken erişim',
      'plan_feature_pro_support': '7/24 sohbet desteği',
      'billing_disclaimer':
          'Ücretli planlar henüz aktif değil. Gösterilen fiyatlar tahminidir ve lansmanda değişebilir.',
      // Common
      'cancel': 'Vazgeç',
      'delete': 'Sil',
      'save': 'Kaydet',
      'close': 'Kapat',
      'free_plan': 'Ücretsiz plan',
      'edit_name': 'İsmi düzenle',
      'ok': 'Tamam',
      // Settings
      'calendar_sync_description':
          'Etkinliklerini içe aktarmak için Google Takvim\'i bağla.',
      'disconnect_google_title': 'Google Takvim Bağlantısını Kes',
      'disconnect_google_body':
          'Bu işlem Google bağlantısını ve eşleştirmeleri kaldırır. LifeStable\'a daha önce aktarılmış etkinlikler, manuel silmediğin sürece kalır.',
      'browser_opened_msg':
          'Tarayıcı açıldı. Erişimi onayladıktan sonra buraya dön.',
      'could_not_open_msg': 'Google giriş sayfası açılamadı.',
      'connect_failed': 'Bağlantı başarısız',
      'sync_failed': 'Senkronizasyon başarısız',
      'sync_complete_msg':
          'Senkronizasyon tamam  •  Oluşturulan: {c}  Güncellenen: {u}  Silinen: {d}',
      'google_disconnected': 'Google Takvim bağlantısı kesildi.',
      'disconnect_failed': 'Bağlantı kesilemedi',
      'no_google_account_msg':
          'Bağlı bir Google hesabı yok. Etkinliklerini içe aktarmak için Bağlan\'a dokun.',
      'account_label': 'Hesap',
      'last_sync_label': 'Son senkron',
      'language_section': 'Dil',
      'language_section_description':
          'Uygulama genelinde kullanılacak dili seç.',
      // Takvim
      'choose_from_gallery': 'Galeriden Seç',
      'take_a_photo': 'Fotoğraf Çek',
      'no_courses_found': 'Görselde ders bulunamadı.',
      'courses_added_count': '{n} ders takvime eklendi!',
      'generic_error': 'Hata',
      'add_to_calendar': 'Takvime Ekle',
      'linked_task': 'Bağlı görev',
      'delete_event_q': 'Etkinlik silinsin mi?',
      'event_type_personal': 'Kişisel',
      'event_type_task': 'Görev',
      'event_type_class': 'Ders',
      'event_type_team': 'Takım',
      // Home dashboard
      'all_clear_today': 'Bugün için hepsi tamam!',
      'you_have_tasks_today': 'Bugün {n} görevin var.',
      'next_up': 'Sırada:',
      'all_clear': 'Hepsi tamam!',
      'no_domains_yet': 'Henüz alan yok',
      // Görevler
      'no_tasks_found': 'Görev bulunamadı.',
      'ai_magic_task': 'AI Sihirli Görev',
      'ai_thinking': 'AI düşünüyor...',
      'ai_task_created': 'Görev AI tarafından oluşturuldu! ✨',
      'ai_event_created': 'Takvim etkinliği AI tarafından oluşturuldu! 📅',
      'ai_event_failed': 'Etkinlik oluşturulamadı',
      'ai_could_not_understand':
          'AI komutu anlayamadı veya bir etkinlik oluşturdu.',
      'magic_btn': 'Sihir!',
      'board_title': 'PANO',
      'col_todo': 'YAPILACAK',
      'col_doing': 'YAPILIYOR',
      'col_done': 'TAMAM',
      'add_task': 'Görev Ekle',
      'ai_prompt_hint': 'örn: Yarın akşam 8 için markete gitmeyi ekle',
      'nav_team': 'Takım',
      'nav_calendar': 'Takvim',
      'nav_dashboard': 'Panel',
      'nav_habit': 'Alışkanlık',
      // Etkinlik oluştur/düzenle
      'new_event_title': 'YENİ ETKİNLİK',
      'edit_event_title': 'ETKİNLİĞİ DÜZENLE',
      'event_title_hint': 'Etkinlik başlığı',
      'event_description_hint': 'Açıklama (isteğe bağlı)',
      'event_section_type': 'Etkinlik Türü',
      'event_section_time': 'Zaman',
      'event_section_team': 'Takım',
      'event_section_assign_members': 'Üye Ata',
      'event_section_link_task': 'Göreve Bağla (isteğe bağlı)',
      'time_start': 'Başlangıç',
      'time_end': 'Bitiş',
      'title_required': 'Başlık gerekli',
      'end_after_start': 'Bitiş, başlangıçtan sonra olmalı',
      'conflicts_label_one': '{n} etkinlikle çakışıyor: {titles}',
      'conflicts_label_many': '{n} etkinlikle çakışıyor: {titles}',
      'loading_teams': 'Takımların yükleniyor…',
      'no_teams_hint':
          'Henüz bir takıma üye değilsin. Takımlar ekranından oluştur veya katıl.',
      'select_a_team': 'Bir takım seç',
      'no_team_option': '— Takım yok —',
      'members_suffix': 'üye',
      'tap_toggle_assignment': 'Atamayı değiştirmek için dokun',
      'no_members_assigned_warning':
          '⚠ Üye atanmadı — en az bir kişi gerekli',
      'loading_tasks': 'Görevler yükleniyor…',
      'no_pending_tasks_hint':
          'Bekleyen görev yok. Alanlar ekranından görev ekle.',
      'select_task_to_link': 'Bağlanacak görevi seç',
      'no_linked_task_option': '— Bağlı görev yok —',
      'delete_event_btn': 'Etkinliği Sil',
      'delete_event_undone': 'Bu işlem geri alınamaz.',
      'save_changes': 'Değişiklikleri Kaydet',
      'create_event': 'Etkinlik Oluştur',
      'select_team_required': 'Bu etkinlik için bir takım seç',
      'assign_member_required': 'En az bir üye atamalısın',
      'time_conflict_title': 'Zaman Çakışması',
      'time_conflict_body':
          'Bu etkinlik şunlarla çakışıyor: {titles}. Yine de kaydedilsin mi?',
      'save_anyway': 'Yine de Kaydet',
      'save_failed': 'Kaydedilemedi',
      // Alan düzenle
      'new_domain': 'Yeni Alan',
      'edit_domain': 'Alanı Düzenle',
      'delete_domain': 'Alanı Sil',
      'delete_domain_confirm': 'Bu alan silinecek. İçindeki görevler silinmeyecek.',
      'new_domain_subtitle':
          'Görevlerini düzenlemek için yeni bir yaşam alanı oluştur.',
      'domain_name': 'Alan Adı',
      'domain_name_hint': 'örn., Okul, Sağlık, İş',
      'description_optional_label': 'Açıklama (İsteğe Bağlı)',
      'domain_description_hint': 'Bu alan ne hakkında?',
      'icon_label': 'Simge',
      'color_label': 'Renk',
      'create_domain': 'Alan Oluştur',
      'required_field': 'Gerekli',
      // Takımlar
      'team_dashboard_title': 'Takım Paneli',
      'no_teams_yet': 'Henüz takım yok.',
      'no_teams_hint_dashboard':
          'Bir tane oluştur veya kodla katıl.',
      'create_team': 'Takım Oluştur',
      'create_btn': 'Oluştur',
      'team_name': 'Takım Adı',
      'objective_optional': 'Amaç (isteğe bağlı)',
      'team_color': 'Takım Rengi',
      'join_with_code': 'Kodla Katıl',
      'team_created_title': 'Takım Oluşturuldu!',
      'share_invite_code':
          'Bu davet kodunu takım arkadaşlarınla paylaş:',
      'invite_code_copied': 'Davet kodu kopyalandı!',
      'tap_to_copy': 'Kopyalamak için dokun',
      'error_label': 'Hata',
      // Takvim sayım çipi
      'event_count_one': '{n} etkinlik',
      'event_count_many': '{n} etkinlik',
      'team_count': '{n} takım',
      'conflict_count': '{n} çakışma',
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
            border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.3)),
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
      onTap: () => S.setLocale(locale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
            colors: [Color(0xFFC9A84C), Color(0xFF9A7B2F)],
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