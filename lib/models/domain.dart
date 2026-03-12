import 'package:cloud_firestore/cloud_firestore.dart';


class Domain {
  final String id; //Domain id -> unique
  final String name; //Domain Name
  final String colorHex; //Color of the domain to show
  final DateTime createdAt; //The creation date of the domain
  final String userId; //user id of the domain's owner

  Domain({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.createdAt,
    required this.userId,
  });

  //Converts a Firestore document into a Domain object
  factory Domain.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    //doc.data() returns raw map, we cast it to use key-value pairs
    return Domain(
      id: doc.id,
      name: data['name'] ?? '', ////If 'name' is null in Firestore, use empty string as fallback
      colorHex: data['color_hex'] ?? '#6200EE',
      createdAt: (data['created_at'] as Timestamp).toDate(), //Converts Firestore Timestamp to Dart DateTime
      userId: data['user_id'] ?? '',
    );
  }

  //Converts Domain object into a Map to save to Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color_hex': colorHex,
      'created_at': Timestamp.fromDate(createdAt), //Converts Dart DateTime back to Firestore Timestamp
      'user_id': userId,
    };
  }
}