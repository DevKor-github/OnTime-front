import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/l10n/app_localizations_en.dart';
import 'package:on_time_front/l10n/app_localizations_ko.dart';

/// Bundled translated search aliases supplement every supported IANA identifier.
/// Displaying a city never rewrites a saved zone.
abstract final class TimeZoneCatalog {
  static Map<String, String> _cities(AppLocalizations l) => {
    'Asia/Seoul': l.zonedCityAsiaSeoul,
    'Asia/Tokyo': l.zonedCityAsiaTokyo,
    'Asia/Shanghai': l.zonedCityAsiaShanghai,
    'Asia/Hong_Kong': l.zonedCityAsiaHongKong,
    'Asia/Taipei': l.zonedCityAsiaTaipei,
    'Asia/Singapore': l.zonedCityAsiaSingapore,
    'Asia/Bangkok': l.zonedCityAsiaBangkok,
    'Asia/Dubai': l.zonedCityAsiaDubai,
    'Asia/Kolkata': l.zonedCityAsiaKolkata,
    'Asia/Kathmandu': l.zonedCityAsiaKathmandu,
    'Europe/London': l.zonedCityEuropeLondon,
    'Europe/Paris': l.zonedCityEuropeParis,
    'Europe/Berlin': l.zonedCityEuropeBerlin,
    'Europe/Rome': l.zonedCityEuropeRome,
    'Europe/Madrid': l.zonedCityEuropeMadrid,
    'Europe/Moscow': l.zonedCityEuropeMoscow,
    'America/New_York': l.zonedCityAmericaNewYork,
    'America/Los_Angeles': l.zonedCityAmericaLosAngeles,
    'America/Chicago': l.zonedCityAmericaChicago,
    'America/Denver': l.zonedCityAmericaDenver,
    'America/Toronto': l.zonedCityAmericaToronto,
    'America/Vancouver': l.zonedCityAmericaVancouver,
    'America/Sao_Paulo': l.zonedCityAmericaSaoPaulo,
    'Australia/Sydney': l.zonedCityAustraliaSydney,
    'Australia/Melbourne': l.zonedCityAustraliaMelbourne,
    'Australia/Perth': l.zonedCityAustraliaPerth,
    'Australia/Lord_Howe': l.zonedCityAustraliaLordHowe,
    'Pacific/Auckland': l.zonedCityPacificAuckland,
    'Pacific/Honolulu': l.zonedCityPacificHonolulu,
    'Pacific/Apia': l.zonedCityPacificApia,
    'Africa/Cairo': l.zonedCityAfricaCairo,
    'Africa/Johannesburg': l.zonedCityAfricaJohannesburg,
    'UTC': l.zonedCityUtc,
  };
  static final _english = _cities(AppLocalizationsEn());
  static final _korean = _cities(AppLocalizationsKo());

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String cityName(String identifier, String languageCode) =>
      (languageCode.split('_').first == 'ko'
          ? _korean
          : _english)[identifier] ??
      identifier.split('/').last.replaceAll('_', ' ');

  static List<String> search(String query) {
    final term = _normalize(query);
    return TimeZoneRules.identifiers
        .where((identifier) {
          final searchable = _normalize(
            '$identifier ${cityName(identifier, 'en')} ${_korean[identifier] ?? ''}',
          );
          return searchable.contains(term);
        })
        .toList(growable: false);
  }
}
