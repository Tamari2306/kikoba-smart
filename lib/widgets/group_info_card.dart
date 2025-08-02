import 'package:flutter/material.dart';

class GroupInfoCard extends StatelessWidget {
  final String groupName;
  final String groupId;
  final String role;

  const GroupInfoCard({
    super.key,
    required this.groupName,
    required this.groupId,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text('Group: $groupName'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: $groupId'),
            Text('Role: ${role[0].toUpperCase()}${role.substring(1)}'),
          ],
        ),
      ),
    );
  }
}
