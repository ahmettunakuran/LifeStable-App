class DomainEntity {
  const DomainEntity({
    required this.id,
    required this.name,
    this.description,
    required this.iconCode,
    required this.colorHex,
  });

  final String id;
  final String name;
  final String? description;
  final int iconCode; // Store IconData.codePoint
  final String colorHex; // Store as #RRGGBB

  DomainEntity copyWith({
    String? id,
    String? name,
    String? description,
    int? iconCode,
    String? colorHex,
  }) {
    return DomainEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconCode: iconCode ?? this.iconCode,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'iconCode': iconCode,
      'colorHex': colorHex,
    };
  }

  factory DomainEntity.fromFirestore(String id, Map<String, dynamic> data) {
    return DomainEntity(
      id: id,
      name: data['name'] as String,
      description: data['description'] as String?,
      iconCode: data['iconCode'] as int? ?? 0xe1af, // Default icon
      colorHex: data['colorHex'] as String? ?? '#7C4DFF',
    );
  }
}
