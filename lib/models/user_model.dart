import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // Changed from enum to String to match your code
  final String? groupId;
  final String? groupName; // Added groupName property
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.groupId,
    this.groupName,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  // Convert from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'member', // Default to member if not specified
      groupId: data['groupId'],
      groupName: data['groupName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert from Map (for cases where you have Map instead of DocumentSnapshot)
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'member',
      groupId: data['groupId'],
      groupName: data['groupName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'groupId': groupId,
      'groupName': groupName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone.toString(),
      'role': role,
      'groupId': groupId,
      'groupName': groupName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  // Copy with method for updates
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? groupId,
    String? groupName,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }

  // Helper methods for role checking
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isMember => role.toLowerCase() == 'member';
  bool get isDiaspora => role.toLowerCase() == 'diaspora';

  // Helper method to get capitalized role
  String get capitalizedRole => role.toUpperCase();

  // Backward compatibility - some screens expect 'uid' instead of 'id'
  String get uid => id;

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, role: $role, groupId: $groupId, groupName: $groupName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Helper class for user roles (if you want to maintain constants)
class UserRoles {
  static const String admin = 'admin';
  static const String member = 'member';
  static const String diaspora = 'diaspora';
  
  static List<String> get all => [admin, member, diaspora];
  
  static bool isValid(String role) {
    return all.contains(role.toLowerCase());
  }
}