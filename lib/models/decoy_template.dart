import 'package:uuid/uuid.dart';

/// A user-defined "fake search result" page shown on the spectator's webapp
/// during decoy mode. The user creates up to 3 of these in Settings → Display
/// and references them per-preset by [id].
class DecoyTemplate {
  /// Max number of thumbnails shown under the main image. Two fits the
  /// non-scrollable footer cleanly without overflow.
  static const int maxThumbnails = 2;

  final String id;
  final String name;            // private label, never shown to spectator
  final String mainImageUrl;
  final List<String> thumbnailUrls; // 0–maxThumbnails entries
  final String title;           // e.g. "Tom Cruise - IMDb"
  final String siteName;        // e.g. "IMDb"
  /// Optional favicon image (overrides text+colors when non-empty). Use this
  /// to drop in the real site logo (IMDb yellow badge, etc.) for a more
  /// convincing look.
  final String faviconImageUrl;
  final String faviconText;     // short text on the badge (1–4 chars)
  final String faviconBgColor;  // hex incl. '#'
  final String faviconTextColor;// hex incl. '#'
  final String copyright;       // bottom copyright disclaimer

  const DecoyTemplate({
    required this.id,
    required this.name,
    required this.mainImageUrl,
    this.thumbnailUrls = const [],
    this.title = '',
    this.siteName = '',
    this.faviconImageUrl = '',
    this.faviconText = 'G',
    this.faviconBgColor = '#1a73e8',
    this.faviconTextColor = '#ffffff',
    this.copyright = 'Images may be subject to copyright. Learn More',
  });

  factory DecoyTemplate.create({
    String? name,
    String mainImageUrl = '',
  }) {
    return DecoyTemplate(
      id: const Uuid().v4(),
      name: name ?? 'New Decoy',
      mainImageUrl: mainImageUrl,
    );
  }

  DecoyTemplate copyWith({
    String? name,
    String? mainImageUrl,
    List<String>? thumbnailUrls,
    String? title,
    String? siteName,
    String? faviconImageUrl,
    String? faviconText,
    String? faviconBgColor,
    String? faviconTextColor,
    String? copyright,
  }) {
    return DecoyTemplate(
      id: id,
      name: name ?? this.name,
      mainImageUrl: mainImageUrl ?? this.mainImageUrl,
      thumbnailUrls: thumbnailUrls ?? List.from(this.thumbnailUrls),
      title: title ?? this.title,
      siteName: siteName ?? this.siteName,
      faviconImageUrl: faviconImageUrl ?? this.faviconImageUrl,
      faviconText: faviconText ?? this.faviconText,
      faviconBgColor: faviconBgColor ?? this.faviconBgColor,
      faviconTextColor: faviconTextColor ?? this.faviconTextColor,
      copyright: copyright ?? this.copyright,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mainImageUrl': mainImageUrl,
        'thumbnailUrls': thumbnailUrls,
        'title': title,
        'siteName': siteName,
        'faviconImageUrl': faviconImageUrl,
        'faviconText': faviconText,
        'faviconBgColor': faviconBgColor,
        'faviconTextColor': faviconTextColor,
        'copyright': copyright,
      };

  factory DecoyTemplate.fromJson(Map<String, dynamic> json) => DecoyTemplate(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Decoy',
        mainImageUrl: json['mainImageUrl'] as String? ?? '',
        thumbnailUrls: (json['thumbnailUrls'] as List?)?.cast<String>() ?? const [],
        title: json['title'] as String? ?? '',
        siteName: json['siteName'] as String? ?? '',
        faviconImageUrl: json['faviconImageUrl'] as String? ?? '',
        faviconText: json['faviconText'] as String? ?? 'G',
        faviconBgColor: json['faviconBgColor'] as String? ?? '#1a73e8',
        faviconTextColor: json['faviconTextColor'] as String? ?? '#ffffff',
        copyright: json['copyright'] as String? ?? 'Images may be subject to copyright. Learn More',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DecoyTemplate && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
