enum VaultRole { owner, member }

/// Represents a member of a shared KeyDiary Vault (e.g. Father as Owner, Child as Co-Guardian)
class VaultMember {
  final String id;
  final String vaultId;
  final String userId;
  final VaultRole role;
  final String encryptedVaultKey;
  final Map<String, dynamic> keyWrapMetadata;
  final DateTime createdAt;
  final String? displayName;
  final String? email;

  const VaultMember({
    required this.id,
    required this.vaultId,
    required this.userId,
    required this.role,
    required this.encryptedVaultKey,
    required this.keyWrapMetadata,
    required this.createdAt,
    this.displayName,
    this.email,
  });

  factory VaultMember.fromJson(Map<String, dynamic> json) {
    return VaultMember(
      id: json['id'] as String,
      vaultId: json['vault_id'] as String,
      userId: json['user_id'] as String,
      role: (json['role'] as String).toUpperCase() == 'OWNER'
          ? VaultRole.owner
          : VaultRole.member,
      encryptedVaultKey: json['encrypted_vault_key'] as String? ?? '',
      keyWrapMetadata: (json['key_wrap_metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vault_id': vaultId,
      'user_id': userId,
      'role': role == VaultRole.owner ? 'OWNER' : 'MEMBER',
      'encrypted_vault_key': encryptedVaultKey,
      'key_wrap_metadata': keyWrapMetadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
