class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String? groupId;
  final String? groupName;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.groupId,
    this.groupName,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      groupId: map['groupId'],
      groupName: map['groupName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'groupId': groupId,
      'groupName': groupName,
    };
  }
}
