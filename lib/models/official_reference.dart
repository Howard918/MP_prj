class OfficialReference {
  const OfficialReference({
    required this.code,
    required this.kind,
    required this.name,
    required this.url,
    required this.scope,
  });

  factory OfficialReference.fromJson(Map<String, dynamic> json) {
    return OfficialReference(
      code: json['code'] as String,
      kind: json['kind'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      scope: json['scope'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'kind': kind,
      'name': name,
      'url': url,
      'scope': scope,
    };
  }

  final String code;
  final String kind;
  final String name;
  final String url;
  final String scope;
}