// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get slogan => 'IPTV-плеер с открытым исходным кодом';

  @override
  String get search => 'Поиск';

  @override
  String get search_live_stream => 'Поиск прямого эфира';

  @override
  String get search_movie => 'Поиск фильма';

  @override
  String get search_series => 'Поиск сериала';

  @override
  String get not_found_in_category => 'Контент в данной категории не найден';

  @override
  String get live_stream_not_found => 'Прямой эфир не найден';

  @override
  String get movie_not_found => 'Фильм не найден';

  @override
  String get see_all => 'Показать все';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get info => 'Информация';

  @override
  String get close => 'Закрыть';

  @override
  String get reset => 'Сбросить';

  @override
  String get delete => 'Удалить';

  @override
  String get cancel => 'Отмена';

  @override
  String get refresh => 'Обновить';

  @override
  String get back => 'Назад';

  @override
  String get clear => 'Очистить';

  @override
  String get clear_all => 'Очистить всё';

  @override
  String get day => 'День';

  @override
  String get clear_all_confirmation_message =>
      'Вы уверены, что хотите удалить всю историю?';

  @override
  String get try_again => 'Попробовать снова';

  @override
  String get history => 'История';

  @override
  String get history_empty_message =>
      'Просмотренные видео будут отображаться здесь';

  @override
  String get live => 'Прямой эфир';

  @override
  String get live_streams => 'Прямые трансляции';

  @override
  String get on_live => 'В эфире';

  @override
  String get other_channels => 'Другие каналы';

  @override
  String get movies => 'Фильмы';

  @override
  String get movie => 'Фильм';

  @override
  String get series_singular => 'Сериал';

  @override
  String get series_plural => 'Сериалы';

  @override
  String get category_id => 'ID категории';

  @override
  String get channel_information => 'Информация о канале';

  @override
  String get channel_id => 'ID канала';

  @override
  String get series_id => 'ID сериала';

  @override
  String get quality => 'Качество';

  @override
  String get stream_type => 'Тип потока';

  @override
  String get format => 'Формат';

  @override
  String get season => 'Сезоны';

  @override
  String episode_count(Object count) {
    return '$count эпизодов';
  }

  @override
  String duration(Object duration) {
    return 'Продолжительность: $duration';
  }

  @override
  String get episode_duration => 'Длительность эпизода';

  @override
  String get creation_date => 'Дата добавления';

  @override
  String get release_date => 'Дата выхода';

  @override
  String get genre => 'Жанр';

  @override
  String get cast => 'В ролях';

  @override
  String get director => 'Режиссер';

  @override
  String get description => 'Описание';

  @override
  String get video_track => 'Видеодорожка';

  @override
  String get audio_track => 'Аудиодорожка';

  @override
  String get subtitle_track => 'Дорожка субтитров';

  @override
  String get settings => 'Настройки';

  @override
  String get general_settings => 'Общие настройки';

  @override
  String get app_language => 'Язык приложения';

  @override
  String get continue_on_background => 'Воспроизведение в фоне';

  @override
  String get continue_on_background_description =>
      'Продолжать воспроизведение, когда приложение свёрнуто';

  @override
  String get refresh_contents => 'Обновить контент';

  @override
  String get subtitle_settings => 'Настройки субтитров';

  @override
  String get subtitle_settings_description => 'Настроить внешний вид субтитров';

  @override
  String get sample_text => 'Пример текста субтитров\nТак это будет выглядеть';

  @override
  String get font_settings => 'Настройки шрифта';

  @override
  String get font_size => 'Размер шрифта';

  @override
  String get font_height => 'Высота строки';

  @override
  String get letter_spacing => 'Интервал между буквами';

  @override
  String get word_spacing => 'Интервал между словами';

  @override
  String get padding => 'Отступы';

  @override
  String get color_settings => 'Настройки цвета';

  @override
  String get text_color => 'Цвет текста';

  @override
  String get background_color => 'Цвет фона';

  @override
  String get style_settings => 'Настройки стиля';

  @override
  String get font_weight => 'Толщина шрифта';

  @override
  String get thin => 'Тонкий';

  @override
  String get normal => 'Обычный';

  @override
  String get medium => 'Средний';

  @override
  String get bold => 'Жирный';

  @override
  String get extreme_bold => 'Очень жирный';

  @override
  String get text_align => 'Выравнивание текста';

  @override
  String get left => 'По левому краю';

  @override
  String get center => 'По центру';

  @override
  String get right => 'По правому краю';

  @override
  String get justify => 'По ширине';

  @override
  String get pick_color => 'Выбрать цвет';

  @override
  String get my_playlists => 'Мои плейлисты';

  @override
  String get create_new_playlist => 'Создать новый плейлист';

  @override
  String get loading_playlists => 'Загрузка плейлистов...';

  @override
  String get playlist_list => 'Список плейлистов';

  @override
  String get playlist_information => 'Информация о плейлисте';

  @override
  String get playlist_name => 'Название плейлиста';

  @override
  String get playlist_name_placeholder => 'Введите название плейлиста';

  @override
  String get playlist_name_required => 'Название плейлиста обязательно';

  @override
  String get playlist_name_min_2 =>
      'Название должно содержать минимум 2 символа';

  @override
  String playlist_deleted(Object name) {
    return '$name удалён';
  }

  @override
  String get playlist_delete_confirmation_title => 'Удалить плейлист';

  @override
  String playlist_delete_confirmation_message(Object name) {
    return 'Вы уверены, что хотите удалить плейлист \'$name\'?\nЭто действие нельзя отменить.';
  }

  @override
  String get empty_playlist_title => 'Пока нет плейлистов';

  @override
  String get empty_playlist_message =>
      'Начните с создания вашего первого плейлиста.\nВы можете добавить плейлисты в формате Xtream Code или M3U.';

  @override
  String get empty_playlist_button => 'Создать первый плейлист';

  @override
  String get favorites => 'Избранное';

  @override
  String get see_all_favorites => 'Посмотреть Все';

  @override
  String get added_to_favorites => 'Добавлено в избранное';

  @override
  String get removed_from_favorites => 'Удалено из избранного';

  @override
  String get remove_from_favorites => 'Удалить из Избранного';

  @override
  String get select_playlist_type => 'Выберите тип плейлиста';

  @override
  String get select_playlist_message =>
      'Выберите тип плейлиста, который хотите создать';

  @override
  String get xtream_code_title => 'Подключение через API URL, логин и пароль';

  @override
  String get xtream_code_description =>
      'Легко подключайтесь с помощью данных от вашего IPTV-провайдера';

  @override
  String get select_playlist_type_footer =>
      'Информация о ваших плейлистах надёжно хранится на устройстве.';

  @override
  String get api_url => 'API URL';

  @override
  String get api_url_required => 'API URL обязателен';

  @override
  String get username => 'Имя пользователя';

  @override
  String get username_placeholder => 'Введите имя пользователя';

  @override
  String get username_required => 'Имя пользователя обязательно';

  @override
  String get username_min_3 =>
      'Имя пользователя должно содержать минимум 3 символа';

  @override
  String get password => 'Пароль';

  @override
  String get password_placeholder => 'Введите пароль';

  @override
  String get password_required => 'Пароль обязателен';

  @override
  String get password_min_3 => 'Пароль должен содержать минимум 3 символа';

  @override
  String get server_url => 'URL сервера';

  @override
  String get submitting => 'Сохранение...';

  @override
  String get submit_create_playlist => 'Сохранить плейлист';

  @override
  String get subscription_details => 'Детали подписки';

  @override
  String subscription_remaining_day(Object days) {
    return 'Подписка: $days';
  }

  @override
  String get remaining_day_title => 'Оставшееся время';

  @override
  String remaining_day(Object days) {
    return '$days дней';
  }

  @override
  String get connected => 'Подключён';

  @override
  String get no_connection => 'Нет соединения';

  @override
  String get expired => 'Истёк';

  @override
  String get active_connection => 'Активное соединение';

  @override
  String get maximum_connection => 'Максимальное соединение';

  @override
  String get server_information => 'Информация о сервере';

  @override
  String get timezone => 'Часовой пояс';

  @override
  String get server_message => 'Сообщение сервера';

  @override
  String get all_datas_are_stored_in_device =>
      'Все данные надёжно хранятся на вашем устройстве';

  @override
  String get url_format_validate_message =>
      'Формат URL должен быть как http://сервер:порт';

  @override
  String get url_format_validate_error =>
      'Введите корректный URL (должен начинаться с http:// или https://)';

  @override
  String get playlist_name_already_exists =>
      'Плейлист с таким названием уже существует';

  @override
  String get invalid_credentials =>
      'Не удалось получить ответ от вашего IPTV-провайдера, проверьте данные';

  @override
  String get error_occurred => 'Произошла ошибка';

  @override
  String get connecting => 'Подключение';

  @override
  String get preparing_categories => 'Подготовка категорий';

  @override
  String preparing_categories_exception(Object error) {
    return 'Не удалось загрузить категории: $error';
  }

  @override
  String get preparing_live_streams => 'Загрузка прямых каналов';

  @override
  String get preparing_live_streams_exception_1 =>
      'Не удалось получить прямые каналы';

  @override
  String preparing_live_streams_exception_2(Object error) {
    return 'Ошибка загрузки прямых каналов: $error';
  }

  @override
  String get preparing_movies => 'Открытие библиотеки фильмов';

  @override
  String get preparing_movies_exception_1 => 'Не удалось получить фильмы';

  @override
  String preparing_movies_exception_2(Object error) {
    return 'Ошибка загрузки фильмов: $error';
  }

  @override
  String get preparing_series => 'Подготовка библиотеки сериалов';

  @override
  String get preparing_series_exception_1 => 'Не удалось получить сериалы';

  @override
  String preparing_series_exception_2(Object error) {
    return 'Ошибка загрузки сериалов: $error';
  }

  @override
  String get preparing_user_info_exception_1 =>
      'Не удалось получить информацию о пользователе';

  @override
  String preparing_user_info_exception_2(Object error) {
    return 'Ошибка загрузки информации о пользователе: $error';
  }

  @override
  String get m3u_playlist_title => 'Добавить плейлист с файлом M3U или URL';

  @override
  String get m3u_playlist_description =>
      'Поддерживает файлы традиционного формата M3U';

  @override
  String get m3u_playlist => 'Плейлист M3U';

  @override
  String get m3u_playlist_load_description =>
      'Загрузить IPTV каналы с файлом плейлиста M3U или URL';

  @override
  String get playlist_name_hint => 'Введите название плейлиста';

  @override
  String get playlist_name_min_length =>
      'Название плейлиста должно содержать не менее 2 символов';

  @override
  String get source_type => 'Тип источника';

  @override
  String get url => 'URL';

  @override
  String get file => 'Файл';

  @override
  String get m3u_url => 'URL M3U';

  @override
  String get m3u_url_hint => 'http://example.com/playlist.m3u';

  @override
  String get m3u_url_required => 'URL M3U обязателен';

  @override
  String get url_format_error => 'Введите правильный формат URL';

  @override
  String get url_scheme_error => 'URL должен начинаться с http:// или https://';

  @override
  String get m3u_file => 'Файл M3U';

  @override
  String get file_selected => 'Файл выбран';

  @override
  String get select_m3u_file => 'Выберите файл M3U (.m3u, .m3u8)';

  @override
  String get please_select_m3u_file => 'Пожалуйста, выберите файл M3U';

  @override
  String get file_selection_error => 'Ошибка при выборе файла';

  @override
  String get processing => 'Обработка...';

  @override
  String get create_playlist => 'Создать плейлист';

  @override
  String get error_occurred_title => 'Произошла ошибка';

  @override
  String get m3u_info_message =>
      'Все данные надежно хранятся на вашем устройстве.\nПоддерживаемые форматы: .m3u, .m3u8\nФормат URL: Должен начинаться с http:// или https://';

  @override
  String get m3u_parse_error => 'Ошибка парсинга M3U';

  @override
  String get loading_m3u => 'Загрузка M3U';

  @override
  String get preparing_m3u_exception_no_source => 'Источник M3U не найден';

  @override
  String get preparing_m3u_exception_empty => 'Файл M3U пуст';

  @override
  String preparing_m3u_exception_parse(Object error) {
    return 'Ошибка парсинга M3U: $error';
  }

  @override
  String get not_categorized => 'Без категории';

  @override
  String get loading_lists => 'Загрузка списков...';

  @override
  String get all => 'Все';

  @override
  String iptv_channels_count(Object count) {
    return 'IPTV каналы ($count)';
  }

  @override
  String get unknown_channel => 'Неизвестный канал';

  @override
  String get live_content => 'ПРЯМОЙ ЭФИР';

  @override
  String get movie_content => 'ФИЛЬМ';

  @override
  String get series_content => 'СЕРИАЛ';

  @override
  String get media_content => 'МЕДИА';

  @override
  String get m3u_error => 'Ошибка M3U';

  @override
  String get episode_short => 'Эп';

  @override
  String season_number(Object number) {
    return '$number сезон';
  }

  @override
  String get image_loading => 'Загрузка изображения...';

  @override
  String get image_not_found => 'Изображение не найдено';

  @override
  String get select_all => 'Выбрать всё';

  @override
  String get deselect_all => 'Отменить выбор всего';

  @override
  String get hide_category => 'Скрыть категории';

  @override
  String get hide_item => 'Скрыть';

  @override
  String get unhide_item => 'Показать';

  @override
  String get item_hidden => 'Элемент скрыт';

  @override
  String get item_unhidden => 'Элемент показан';

  @override
  String get rating => 'рейтинг';

  @override
  String get remove_from_history => 'Удалить из истории';

  @override
  String get remove_from_history_confirmation =>
      'Вы уверены, что хотите удалить этот элемент из истории просмотров?';

  @override
  String get remove => 'Удалить';

  @override
  String get clear_old_records => 'Очистить старые записи';

  @override
  String get clear_old_records_confirmation =>
      'Вы уверены, что хотите удалить записи просмотров старше 30 дней?';

  @override
  String get clear_old => 'Очистить старые';

  @override
  String get clear_all_history => 'Очистить всю историю';

  @override
  String get clear_all_history_confirmation =>
      'Вы уверены, что хотите удалить всю историю просмотров?';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get theme => 'Тема';

  @override
  String get standard => 'По умолчанию';

  @override
  String get light => 'Светлый';

  @override
  String get dark => 'Темный';

  @override
  String get trailer => 'трейлер';

  @override
  String get new_ep => 'новый';

  @override
  String get continue_watching => 'Продолжить просмотр';

  @override
  String get start_watching => 'Начать просмотр';

  @override
  String continue_watching_label(String season, String episode) {
    return 'Продолжить: Сезон $season Серия $episode';
  }

  @override
  String get player_settings => 'Настройки плеера';

  @override
  String get brightness_gesture => 'Жест яркости';

  @override
  String get brightness_gesture_description =>
      'Управление яркостью вертикальным свайпом слева';

  @override
  String get volume_gesture => 'Жест громкости';

  @override
  String get volume_gesture_description =>
      'Управление громкостью вертикальным свайпом справа';

  @override
  String get seek_gesture => 'Жест поиска';

  @override
  String get seek_gesture_description => 'Поиск горизонтальным свайпом';

  @override
  String get speed_up_on_long_press => 'Ускорение при долгом нажатии';

  @override
  String get speed_up_on_long_press_description =>
      'Ускорение воспроизведения при долгом нажатии';

  @override
  String get seek_on_double_tap => 'Поиск при двойном нажатии';

  @override
  String get seek_on_double_tap_description =>
      'Поиск вперед/назад двойным нажатием';

  @override
  String get copied_to_clipboard => 'Скопировано в буфер обмена';

  @override
  String get about => 'О приложении';

  @override
  String get app_version => 'Версия приложения';

  @override
  String get support_on_github => 'Поддержать на GitHub';

  @override
  String get support_on_github_description => 'Внести вклад в проект на GitHub';

  @override
  String get select_channel => 'Выбрать Канал';

  @override
  String get episodes => 'Эпизоды';

  @override
  String get categories => 'Категории';

  @override
  String get seasons => 'Сезоны';

  @override
  String season_number_format(int number) {
    return 'Сезон $number';
  }

  @override
  String episode_count_format(int count) {
    return '$count эпизодов';
  }

  @override
  String channel_count_format(int count) {
    return '$count каналов';
  }

  @override
  String get video_info => 'Информация о Видео';

  @override
  String get video_info_not_found => 'Информация о видео не найдена';

  @override
  String get name => 'Название';

  @override
  String get content_type => 'Тип Контента';

  @override
  String get plot => 'Сюжет';

  @override
  String get duration_unknown => 'Неизвестно';

  @override
  String get url_copied_to_clipboard => 'URL скопирован в буфер обмена';

  @override
  String get stream_id => 'ID Потока';

  @override
  String get epg_channel_id => 'ID Канала EPG';

  @override
  String get category => 'Категория';

  @override
  String get add_to_favorites => 'Добавить в Избранное';

  @override
  String get no_tracks_available => 'Дорожки недоступны';

  @override
  String get live_stream_content_type => 'Прямой Эфир';

  @override
  String get movie_content_type => 'Фильм';

  @override
  String get series_content_type => 'Сериал';

  @override
  String get last_update => 'Последнее Обновление';

  @override
  String get minutes => 'мин';

  @override
  String get duration_label => 'Продолжительность';

  @override
  String get no_favorites => 'Пока нет избранного';

  @override
  String get add_favorites_hint =>
      'Нажмите на значок сердца на любом контенте, чтобы добавить его в избранное';

  @override
  String get mark_as_watched => 'Отметить как просмотренное';

  @override
  String get unmark_as_watched => 'Снять отметку просмотра';

  @override
  String get marked_as_watched => 'Отмечено как просмотренное';

  @override
  String get unmarked_as_watched => 'Отметка просмотра снята';

  @override
  String get hidden_items => 'Скрытые элементы';

  @override
  String get no_hidden_items => 'Нет скрытых элементов';

  @override
  String get hidden_items_hint =>
      'Элементы, которые вы отметите как просмотренные, появятся здесь';

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
