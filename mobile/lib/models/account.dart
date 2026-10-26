class Account {
  final String id;
  final String type; // 'PERSONAL' | 'ORGANIZATION'
  final String displayName;
  final String? taxId;
  final String? accessRole;

  const Account({
    required this.id,
    required this.type,
    required this.displayName,
    this.taxId,
    this.accessRole,
  });

  bool get isOrganization => type == 'ORGANIZATION';
  bool get canManageMembers => isOrganization && accessRole == 'OWNER';

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'PERSONAL',
      displayName: json['displayName'] as String? ?? '',
      taxId: json['taxId'] as String?,
      accessRole: json['accessRole'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'displayName': displayName,
    if (taxId != null) 'taxId': taxId,
    if (accessRole != null) 'accessRole': accessRole,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
