// Script temporal para corregir el rol de la inmobiliaria
// Ejecutar con: dart run fix_inmobiliaria_role.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Inicializar Firebase
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  
  // UID del usuario a corregir
  const uid = 'OIICjew7cWNE2JxbxDDdBkfC5Ry2';
  
  try {
    await firestore.collection('users').doc(uid).update({
      'role': 'inmobiliaria_empresa',
      'status': 'inmobiliaria_empresa',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ Rol actualizado correctamente para el usuario $uid');
  } catch (e) {
    print('❌ Error al actualizar: $e');
  }
}
