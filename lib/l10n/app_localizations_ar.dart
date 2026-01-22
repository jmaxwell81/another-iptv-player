// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get slogan => 'مشغل IPTV مفتوح المصدر';

  @override
  String get search => 'بحث';

  @override
  String get search_live_stream => 'البحث في البث المباشر';

  @override
  String get search_movie => 'البحث في الأفلام';

  @override
  String get search_series => 'البحث في المسلسلات';

  @override
  String get not_found_in_category => 'لم يتم العثور على محتوى في هذه الفئة';

  @override
  String get live_stream_not_found => 'لم يتم العثور على بث مباشر';

  @override
  String get movie_not_found => 'لم يتم العثور على فيلم';

  @override
  String get see_all => 'عرض الكل';

  @override
  String get preview => 'معاينة';

  @override
  String get info => 'معلومات';

  @override
  String get close => 'إغلاق';

  @override
  String get reset => 'إعادة تعيين';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get refresh => 'تحديث';

  @override
  String get back => 'رجوع';

  @override
  String get clear => 'مسح';

  @override
  String get clear_all => 'مسح الكل';

  @override
  String get day => 'يوم';

  @override
  String get clear_all_confirmation_message =>
      'هل أنت متأكد من رغبتك في حذف كل السجل؟';

  @override
  String get try_again => 'حاول مرة أخرى';

  @override
  String get history => 'السجل';

  @override
  String get history_empty_message => 'ستظهر مقاطع الفيديو التي شاهدتها هنا';

  @override
  String get live => 'مباشر';

  @override
  String get live_streams => 'البث المباشر';

  @override
  String get on_live => 'مباشر';

  @override
  String get other_channels => 'قنوات أخرى';

  @override
  String get movies => 'أفلام';

  @override
  String get movie => 'فيلم';

  @override
  String get series_singular => 'مسلسل';

  @override
  String get series_plural => 'مسلسلات';

  @override
  String get category_id => 'معرف الفئة';

  @override
  String get channel_information => 'معلومات القناة';

  @override
  String get channel_id => 'معرف القناة';

  @override
  String get series_id => 'معرف المسلسل';

  @override
  String get quality => 'الجودة';

  @override
  String get stream_type => 'نوع البث';

  @override
  String get format => 'التنسيق';

  @override
  String get season => 'المواسم';

  @override
  String episode_count(Object count) {
    return '$count حلقة';
  }

  @override
  String duration(Object duration) {
    return 'المدة: $duration';
  }

  @override
  String get episode_duration => 'مدة الحلقة';

  @override
  String get creation_date => 'تاريخ الإضافة';

  @override
  String get release_date => 'تاريخ الإصدار';

  @override
  String get genre => 'النوع';

  @override
  String get cast => 'فريق التمثيل';

  @override
  String get director => 'المخرج';

  @override
  String get description => 'الوصف';

  @override
  String get video_track => 'مسار الفيديو';

  @override
  String get audio_track => 'مسار الصوت';

  @override
  String get subtitle_track => 'مسار الترجمة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get general_settings => 'الإعدادات العامة';

  @override
  String get app_language => 'لغة التطبيق';

  @override
  String get continue_on_background => 'متابعة التشغيل في الخلفية';

  @override
  String get continue_on_background_description =>
      'متابعة التشغيل حتى عندما يكون التطبيق في الخلفية';

  @override
  String get refresh_contents => 'تحديث المحتوى';

  @override
  String get subtitle_settings => 'إعدادات الترجمة';

  @override
  String get subtitle_settings_description => 'تخصيص مظهر الترجمة';

  @override
  String get sample_text => 'نص ترجمة تجريبي\nسيبدو هكذا';

  @override
  String get font_settings => 'إعدادات الخط';

  @override
  String get font_size => 'حجم الخط';

  @override
  String get font_height => 'ارتفاع السطر';

  @override
  String get letter_spacing => 'تباعد الأحرف';

  @override
  String get word_spacing => 'تباعد الكلمات';

  @override
  String get padding => 'الحشو';

  @override
  String get color_settings => 'إعدادات الألوان';

  @override
  String get text_color => 'لون النص';

  @override
  String get background_color => 'لون الخلفية';

  @override
  String get style_settings => 'إعدادات النمط';

  @override
  String get font_weight => 'سُمك الخط';

  @override
  String get thin => 'رفيع';

  @override
  String get normal => 'عادي';

  @override
  String get medium => 'متوسط';

  @override
  String get bold => 'عريض';

  @override
  String get extreme_bold => 'عريض جداً';

  @override
  String get text_align => 'محاذاة النص';

  @override
  String get left => 'يسار';

  @override
  String get center => 'وسط';

  @override
  String get right => 'يمين';

  @override
  String get justify => 'ضبط';

  @override
  String get pick_color => 'اختر لوناً';

  @override
  String get my_playlists => 'قوائم التشغيل الخاصة بي';

  @override
  String get create_new_playlist => 'إنشاء قائمة تشغيل جديدة';

  @override
  String get loading_playlists => 'جارٍ تحميل قوائم التشغيل...';

  @override
  String get playlist_list => 'قائمة التشغيل';

  @override
  String get playlist_information => 'معلومات قائمة التشغيل';

  @override
  String get playlist_name => 'اسم قائمة التشغيل';

  @override
  String get playlist_name_placeholder => 'أدخل اسماً لقائمة التشغيل';

  @override
  String get playlist_name_required => 'اسم قائمة التشغيل مطلوب';

  @override
  String get playlist_name_min_2 => 'يجب أن يحتوي الاسم على حرفين على الأقل';

  @override
  String playlist_deleted(Object name) {
    return 'تم حذف $name';
  }

  @override
  String get playlist_delete_confirmation_title => 'حذف قائمة التشغيل';

  @override
  String playlist_delete_confirmation_message(Object name) {
    return 'هل أنت متأكد من رغبتك في حذف قائمة التشغيل \'$name\'؟\nلا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get empty_playlist_title => 'لا توجد قوائم تشغيل بعد';

  @override
  String get empty_playlist_message =>
      'ابدأ بإنشاء قائمة التشغيل الأولى.\nيمكنك إضافة قوائم تشغيل بتنسيق Xtream Code أو M3U.';

  @override
  String get empty_playlist_button => 'إنشاء قائمة التشغيل الأولى';

  @override
  String get favorites => 'المفضلة';

  @override
  String get see_all_favorites => 'عرض الكل';

  @override
  String get added_to_favorites => 'تمت الإضافة إلى المفضلة';

  @override
  String get removed_from_favorites => 'تمت الإزالة من المفضلة';

  @override
  String get remove_from_favorites => 'إزالة من المفضلة';

  @override
  String get select_playlist_type => 'اختر نوع قائمة التشغيل';

  @override
  String get select_playlist_message =>
      'اختر نوع قائمة التشغيل التي تريد إنشاءها';

  @override
  String get xtream_code_title =>
      'الاتصال باستخدام API URL واسم المستخدم وكلمة المرور';

  @override
  String get xtream_code_description =>
      'اتصل بسهولة باستخدام معلومات مزود IPTV الخاص بك';

  @override
  String get select_playlist_type_footer =>
      'يتم تخزين معلومات قائمة التشغيل بأمان على جهازك.';

  @override
  String get api_url => 'رابط API';

  @override
  String get api_url_required => 'رابط API مطلوب';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get username_placeholder => 'أدخل اسم المستخدم';

  @override
  String get username_required => 'اسم المستخدم مطلوب';

  @override
  String get username_min_3 => 'يجب أن يحتوي اسم المستخدم على 3 أحرف على الأقل';

  @override
  String get password => 'كلمة المرور';

  @override
  String get password_placeholder => 'أدخل كلمة المرور';

  @override
  String get password_required => 'كلمة المرور مطلوبة';

  @override
  String get password_min_3 => 'يجب أن تحتوي كلمة المرور على 3 أحرف على الأقل';

  @override
  String get server_url => 'رابط الخادم';

  @override
  String get submitting => 'جارٍ الحفظ...';

  @override
  String get submit_create_playlist => 'حفظ قائمة التشغيل';

  @override
  String get subscription_details => 'تفاصيل الاشتراك';

  @override
  String subscription_remaining_day(Object days) {
    return 'الاشتراك: $days';
  }

  @override
  String get remaining_day_title => 'الوقت المتبقي';

  @override
  String remaining_day(Object days) {
    return '$days يوم';
  }

  @override
  String get connected => 'متصل';

  @override
  String get no_connection => 'لا يوجد اتصال';

  @override
  String get expired => 'منتهي الصلاحية';

  @override
  String get active_connection => 'اتصال نشط';

  @override
  String get maximum_connection => 'الحد الأقصى للاتصال';

  @override
  String get server_information => 'معلومات الخادم';

  @override
  String get timezone => 'المنطقة الزمنية';

  @override
  String get server_message => 'رسالة الخادم';

  @override
  String get all_datas_are_stored_in_device =>
      'يتم تخزين جميع البيانات بأمان على جهازك';

  @override
  String get url_format_validate_message =>
      'يجب أن يكون تنسيق الرابط مثل http://server:port';

  @override
  String get url_format_validate_error =>
      'يرجى إدخال رابط صحيح (يجب أن يبدأ بـ http:// أو https://)';

  @override
  String get playlist_name_already_exists =>
      'توجد قائمة تشغيل بهذا الاسم بالفعل';

  @override
  String get invalid_credentials =>
      'تعذر الحصول على استجابة من مزود IPTV، يرجى التحقق من معلوماتك';

  @override
  String get error_occurred => 'حدث خطأ';

  @override
  String get connecting => 'جارٍ الاتصال';

  @override
  String get preparing_categories => 'جارٍ تحضير الفئات';

  @override
  String preparing_categories_exception(Object error) {
    return 'تعذر تحميل الفئات: $error';
  }

  @override
  String get preparing_live_streams => 'جارٍ تحميل القنوات المباشرة';

  @override
  String get preparing_live_streams_exception_1 =>
      'تعذر الحصول على القنوات المباشرة';

  @override
  String preparing_live_streams_exception_2(Object error) {
    return 'خطأ في تحميل القنوات المباشرة: $error';
  }

  @override
  String get preparing_movies => 'جارٍ فتح مكتبة الأفلام';

  @override
  String get preparing_movies_exception_1 => 'تعذر الحصول على الأفلام';

  @override
  String preparing_movies_exception_2(Object error) {
    return 'خطأ في تحميل الأفلام: $error';
  }

  @override
  String get preparing_series => 'جارٍ تحضير مكتبة المسلسلات';

  @override
  String get preparing_series_exception_1 => 'تعذر الحصول على المسلسلات';

  @override
  String preparing_series_exception_2(Object error) {
    return 'خطأ في تحميل المسلسلات: $error';
  }

  @override
  String get preparing_user_info_exception_1 =>
      'تعذر الحصول على معلومات المستخدم';

  @override
  String preparing_user_info_exception_2(Object error) {
    return 'خطأ في تحميل معلومات المستخدم: $error';
  }

  @override
  String get m3u_playlist_title => 'إضافة قائمة تشغيل بملف M3U أو رابط';

  @override
  String get m3u_playlist_description => 'يدعم ملفات تنسيق M3U التقليدية';

  @override
  String get m3u_playlist => 'قائمة تشغيل M3U';

  @override
  String get m3u_playlist_load_description =>
      'تحميل قنوات IPTV بملف قائمة تشغيل M3U أو رابط';

  @override
  String get playlist_name_hint => 'أدخل اسم قائمة التشغيل';

  @override
  String get playlist_name_min_length =>
      'يجب أن يكون اسم قائمة التشغيل على الأقل حرفين';

  @override
  String get source_type => 'نوع المصدر';

  @override
  String get url => 'رابط';

  @override
  String get file => 'ملف';

  @override
  String get m3u_url => 'رابط M3U';

  @override
  String get m3u_url_hint => 'http://example.com/playlist.m3u';

  @override
  String get m3u_url_required => 'رابط M3U مطلوب';

  @override
  String get url_format_error => 'أدخل تنسيق رابط صحيح';

  @override
  String get url_scheme_error => 'يجب أن يبدأ الرابط بـ http:// أو https://';

  @override
  String get m3u_file => 'ملف M3U';

  @override
  String get file_selected => 'تم اختيار الملف';

  @override
  String get select_m3u_file => 'اختر ملف M3U (.m3u, .m3u8)';

  @override
  String get please_select_m3u_file => 'يرجى اختيار ملف M3U';

  @override
  String get file_selection_error => 'حدث خطأ أثناء اختيار الملف';

  @override
  String get processing => 'جارٍ المعالجة...';

  @override
  String get create_playlist => 'إنشاء قائمة التشغيل';

  @override
  String get error_occurred_title => 'حدث خطأ';

  @override
  String get m3u_info_message =>
      'جميع البيانات محفوظة بأمان على جهازك.\nالتنسيقات المدعومة: .m3u, .m3u8\nتنسيق الرابط: يجب أن يبدأ بـ http:// أو https://';

  @override
  String get m3u_parse_error => 'خطأ في تحليل M3U';

  @override
  String get loading_m3u => 'تحميل M3U';

  @override
  String get preparing_m3u_exception_no_source => 'لم يتم العثور على مصدر M3U';

  @override
  String get preparing_m3u_exception_empty => 'ملف M3U فارغ';

  @override
  String preparing_m3u_exception_parse(Object error) {
    return 'خطأ في تحليل M3U: $error';
  }

  @override
  String get not_categorized => 'غير مصنف';

  @override
  String get loading_lists => 'تحميل القوائم...';

  @override
  String get all => 'الكل';

  @override
  String iptv_channels_count(Object count) {
    return 'قنوات IPTV ($count)';
  }

  @override
  String get unknown_channel => 'قناة غير معروفة';

  @override
  String get live_content => 'مباشر';

  @override
  String get movie_content => 'فيلم';

  @override
  String get series_content => 'مسلسل';

  @override
  String get media_content => 'وسائط';

  @override
  String get m3u_error => 'خطأ M3U';

  @override
  String get episode_short => 'حلقة';

  @override
  String season_number(Object number) {
    return 'الموسم $number';
  }

  @override
  String get image_loading => 'تحميل الصورة...';

  @override
  String get image_not_found => 'الصورة غير موجودة';

  @override
  String get select_all => 'حدد الكل';

  @override
  String get deselect_all => 'إلغاء تحديد الكل';

  @override
  String get hide_category => 'إخفاء الفئة';

  @override
  String get hide_item => 'إخفاء';

  @override
  String get unhide_item => 'إظهار';

  @override
  String get item_hidden => 'تم إخفاء العنصر';

  @override
  String get item_unhidden => 'تم إظهار العنصر';

  @override
  String get rating => 'تصنيف';

  @override
  String get remove_from_history => 'إزالة من السجل';

  @override
  String get remove_from_history_confirmation =>
      'هل أنت متأكد من أنك تريد إزالة هذا العنصر من سجل المشاهدة؟';

  @override
  String get remove => 'إزالة';

  @override
  String get clear_old_records => 'مسح السجلات القديمة';

  @override
  String get clear_old_records_confirmation =>
      'هل أنت متأكد من أنك تريد حذف سجلات المشاهدة الأقدم من 30 يومًا؟';

  @override
  String get clear_old => 'مسح القديم';

  @override
  String get clear_all_history => 'مسح كل السجل';

  @override
  String get clear_all_history_confirmation =>
      'هل أنت متأكد من أنك تريد حذف كل سجل المشاهدة؟';

  @override
  String get appearance => 'المظهر';

  @override
  String get theme => 'سمة';

  @override
  String get standard => 'قياسي';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get trailer => 'الإعلان';

  @override
  String get new_ep => 'جديد';

  @override
  String get continue_watching => 'متابعة المشاهدة';

  @override
  String get start_watching => 'ابدأ المشاهدة';

  @override
  String continue_watching_label(String season, String episode) {
    return 'متابعة: الموسم $season الحلقة $episode';
  }

  @override
  String get player_settings => 'إعدادات المشغل';

  @override
  String get brightness_gesture => 'إيماءة السطوع';

  @override
  String get brightness_gesture_description =>
      'التحكم في السطوع عن طريق السحب عموديًا على الجانب الأيسر';

  @override
  String get volume_gesture => 'إيماءة الصوت';

  @override
  String get volume_gesture_description =>
      'التحكم في الصوت عن طريق السحب عموديًا على الجانب الأيمن';

  @override
  String get seek_gesture => 'إيماءة البحث';

  @override
  String get seek_gesture_description => 'البحث عن طريق السحب أفقيًا';

  @override
  String get speed_up_on_long_press => 'تسريع عند الضغط الطويل';

  @override
  String get speed_up_on_long_press_description =>
      'تسريع التشغيل عند الضغط الطويل';

  @override
  String get seek_on_double_tap => 'البحث عند النقر المزدوج';

  @override
  String get seek_on_double_tap_description =>
      'البحث للأمام/للخلف بالنقر المزدوج';

  @override
  String get copied_to_clipboard => 'تم النسخ إلى الحافظة';

  @override
  String get about => 'حول';

  @override
  String get app_version => 'إصدار التطبيق';

  @override
  String get support_on_github => 'دعم على GitHub';

  @override
  String get support_on_github_description => 'ساهم في المشروع على GitHub';

  @override
  String get select_channel => 'اختر القناة';

  @override
  String get episodes => 'حلقات';

  @override
  String get categories => 'الفئات';

  @override
  String get seasons => 'المواسم';

  @override
  String season_number_format(int number) {
    return 'الموسم $number';
  }

  @override
  String episode_count_format(int count) {
    return '$count حلقة';
  }

  @override
  String channel_count_format(int count) {
    return '$count قناة';
  }

  @override
  String get video_info => 'معلومات الفيديو';

  @override
  String get video_info_not_found => 'لم يتم العثور على معلومات الفيديو';

  @override
  String get name => 'الاسم';

  @override
  String get content_type => 'نوع المحتوى';

  @override
  String get plot => 'الحبكة';

  @override
  String get duration_unknown => 'غير معروف';

  @override
  String get url_copied_to_clipboard => 'تم نسخ الرابط إلى الحافظة';

  @override
  String get stream_id => 'معرف البث';

  @override
  String get epg_channel_id => 'معرف قناة EPG';

  @override
  String get category => 'الفئة';

  @override
  String get add_to_favorites => 'إضافة إلى المفضلة';

  @override
  String get no_tracks_available => 'لا توجد مسارات متاحة';

  @override
  String get live_stream_content_type => 'بث مباشر';

  @override
  String get movie_content_type => 'فيلم';

  @override
  String get series_content_type => 'مسلسل';

  @override
  String get last_update => 'آخر تحديث';

  @override
  String get minutes => 'دقيقة';

  @override
  String get duration_label => 'المدة';

  @override
  String get no_favorites => 'لا توجد مفضلات بعد';

  @override
  String get add_favorites_hint =>
      'اضغط على أيقونة القلب على أي محتوى لإضافته إلى مفضلاتك';

  @override
  String get mark_as_watched => 'وضع علامة كمشاهَد';

  @override
  String get unmark_as_watched => 'إزالة علامة المشاهَد';

  @override
  String get marked_as_watched => 'تم وضع علامة كمشاهَد';

  @override
  String get unmarked_as_watched => 'تم إزالة علامة المشاهَد';

  @override
  String get hidden_items => 'العناصر المخفية';

  @override
  String get no_hidden_items => 'لا توجد عناصر مخفية';

  @override
  String get hidden_items_hint =>
      'ستظهر العناصر التي تضع عليها علامة كمشاهَدة هنا';

  @override
  String get tv_guide => 'TV Guide';

  @override
  String get epg => 'EPG';

  @override
  String get epg_settings => 'EPG Settings';

  @override
  String get epg_url => 'EPG URL';

  @override
  String get epg_url_default => 'Use Default URL';

  @override
  String get epg_url_custom => 'Custom EPG URL';

  @override
  String get refresh_epg => 'Refresh EPG';

  @override
  String get clear_epg_data => 'Clear EPG Data';

  @override
  String get epg_last_updated => 'Last Updated';

  @override
  String get epg_program_count => 'Programs';

  @override
  String get epg_channel_count => 'Channels';

  @override
  String get no_epg_data => 'No EPG data available';

  @override
  String get fetching_epg => 'Fetching EPG data...';

  @override
  String get epg_fetch_success => 'EPG data updated successfully';

  @override
  String get epg_fetch_error => 'Failed to fetch EPG data';

  @override
  String get votes => 'votes';

  @override
  String get similar_content => 'Similar Content';

  @override
  String similar_content_available(Object count) {
    return '$count similar titles found';
  }

  @override
  String get keywords => 'Keywords';

  @override
  String get tmdb_rating => 'TMDB Rating';

  @override
  String get external_services => 'External Services';

  @override
  String get opensubtitles_api_key => 'OpenSubtitles API Key';

  @override
  String get tmdb_api_key => 'TMDB API Key';

  @override
  String get api_key_not_set => 'Not configured';

  @override
  String get api_key_configured => 'Configured';

  @override
  String get enter_api_key => 'Enter API Key';

  @override
  String get api_key_saved => 'API key saved';

  @override
  String get preferred_subtitle_language => 'Preferred Subtitle Language';

  @override
  String get auto_download_subtitles => 'Auto-download Subtitles';

  @override
  String get auto_download_subtitles_desc =>
      'Automatically download subtitles when playing content';

  @override
  String get available_sources => 'Available Sources';

  @override
  String get recommended => 'Recommended';

  @override
  String source_count(int count) {
    return '$count sources';
  }

  @override
  String get consolidation_settings => 'Content Consolidation';

  @override
  String get enable_consolidation => 'Enable Consolidation';

  @override
  String get enable_consolidation_desc =>
      'Merge duplicate content from multiple sources';

  @override
  String get preferred_quality => 'Preferred Quality';

  @override
  String get preferred_language => 'Preferred Language';

  @override
  String get quality_4k => '4K / UHD';

  @override
  String get quality_1080p => '1080p / Full HD';

  @override
  String get quality_720p => '720p / HD';

  @override
  String get quality_sd => 'SD';

  @override
  String get content_filters => 'Content Filters';

  @override
  String get language_filter => 'Language';

  @override
  String get filter_rules => 'Rules';

  @override
  String get tag_mappings => 'Mappings';

  @override
  String get enable_language_filter => 'Enable Language Filter';

  @override
  String get enable_language_filter_desc =>
      'Show only content matching your preferred languages';

  @override
  String get hide_unknown_language => 'Hide Unknown Language';

  @override
  String get hide_unknown_language_desc =>
      'Hide content with no detected language tag';

  @override
  String get preferred_languages => 'Preferred Languages';

  @override
  String get preferred_languages_desc => 'Select the languages you want to see';

  @override
  String get matching_tags => 'Matching Tags';

  @override
  String get add_filter_rule => 'Add Filter Rule';

  @override
  String get edit_filter_rule => 'Edit Filter Rule';

  @override
  String get no_filter_rules => 'No Filter Rules';

  @override
  String get no_filter_rules_desc =>
      'Add rules to hide or show content based on name patterns';

  @override
  String get pattern => 'Pattern';

  @override
  String get pattern_regex_help =>
      'Use regular expressions for advanced matching';

  @override
  String get pattern_wildcard_help => 'Use * as wildcard (e.g., *spanish*)';

  @override
  String get use_regex => 'Use Regular Expression';

  @override
  String get use_regex_desc => 'Enable regex pattern matching';

  @override
  String get hide_matching => 'Hide Matching';

  @override
  String get hide_matching_desc => 'Hide items that match this pattern';

  @override
  String get show_only_matching_desc =>
      'Show only items that match this pattern';

  @override
  String get apply_to => 'Apply To';

  @override
  String get content_items => 'Content Items';

  @override
  String get category_names => 'Category Names';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get search_mappings => 'Search mappings...';

  @override
  String get add => 'Add';

  @override
  String get add_tag_mapping => 'Add Tag Mapping';

  @override
  String get tag => 'Tag';

  @override
  String get language => 'Language';

  @override
  String get bulk_hide_content => 'Bulk Hide Content';

  @override
  String get hide_selected => 'Hide Selected';

  @override
  String get show_only_selected => 'Show Only Selected';

  @override
  String get apply_to_all_categories => 'Apply to All Categories';

  @override
  String get items_matching => 'items matching';

  @override
  String get enter_pattern_to_search => 'Enter a pattern to search';

  @override
  String get no_matches_found => 'No matches found';

  @override
  String hide_count(int count) {
    return 'Hide $count';
  }

  @override
  String get create_filter => 'Create Filter';

  @override
  String get quick_hide_pattern => 'Quick Hide by Pattern';

  @override
  String get hide => 'Hide';

  @override
  String get custom_categories => 'Custom Categories';

  @override
  String get custom_categories_desc =>
      'Create your own categories to organize content';

  @override
  String get no_custom_categories => 'No Custom Categories';

  @override
  String get create_category => 'Create Category';

  @override
  String get edit_category => 'Edit Category';

  @override
  String get delete_category => 'Delete Category';

  @override
  String delete_category_confirm(String name, int count) {
    return 'Delete \"$name\"? This will remove $count items from this category.';
  }

  @override
  String get category_name => 'Category Name';

  @override
  String get icon => 'Icon';

  @override
  String get content_type_filter => 'Content Type';

  @override
  String get view_items => 'View Items';

  @override
  String get items => 'items';

  @override
  String get no_items_in_category => 'No items in this category';

  @override
  String get create => 'Create';

  @override
  String get bulk_move_items => 'Bulk Move Items';

  @override
  String get search_pattern => 'Search Pattern';

  @override
  String get search_hint => 'Search by category or item name...';

  @override
  String get search_by_category => 'Search by Category';

  @override
  String get search_by_name => 'Search by Name';

  @override
  String get items_found => 'items found';

  @override
  String get enter_search_pattern => 'Enter a search pattern to find items';

  @override
  String get name_matches => 'Name Matches';

  @override
  String get move_to_category => 'Move to Category';

  @override
  String get new_category => 'New Category';

  @override
  String get new_category_name => 'New Category Name';

  @override
  String get select_category => 'Select a category';

  @override
  String move_count(int count) {
    return 'Move $count items';
  }

  @override
  String get bulk_add_items => 'Bulk Add Items';

  @override
  String get no_content_loaded =>
      'No content available. Please load a playlist first.';
}
