import 'package:cloud_firestore/cloud_firestore.dart';

class InmobiliariaCompany {
  final String id;
  final String companyName;
  final String ruc;
  final String address;
  final String phoneNumber;
  final String email;
  final String representativeName;
  final String? companyLogo;
  final DateTime createdAt;
  final bool isVerified;

  InmobiliariaCompany({
    required this.id,
    required this.companyName,
    required this.ruc,
    required this.address,
    required this.phoneNumber,
    required this.email,
    required this.representativeName,
    this.companyLogo,
    required this.createdAt,
    this.isVerified = false,
  });

  factory InmobiliariaCompany.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InmobiliariaCompany(
      id: doc.id,
      companyName: data['companyName'] ?? '',
      ruc: data['ruc'] ?? '',
      address: data['address'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
      representativeName: data['representativeName'] ?? '',
      companyLogo: data['companyLogo'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isVerified: data['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'ruc': ruc,
      'address': address,
      'phoneNumber': phoneNumber,
      'email': email,
      'representativeName': representativeName,
      'companyLogo': companyLogo,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVerified': isVerified,
      'role': 'inmobiliaria_empresa',
    };
  }
}
