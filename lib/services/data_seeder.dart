// services/data_seeder.dart

import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// Usamos DateTime.now() para la fecha de creación en los datos de prueba
final DateTime now = DateTime.now();

// --- UIDs DE PRUEBA ---
const String UID_PROPIETARIO_A = 'test_owner_A_uid';
const String UID_CLIENTE_B = 'test_client_B_uid';
const String UID_PROPIETARIO_C = 'test_owner_C_uid';
const String UID_CLIENTE_D = 'test_client_D_uid';

final List<Map<String, dynamic>> testUsers = [
  {
    "uid": UID_PROPIETARIO_A,
    "email": "propietario.a@app.com",
    "display_name": "Agente Max Test (SCZ)",
    "phone": "+59170012345",
    "user_role": "Agente",
    "created_at": now,
  },
  {
    "uid": UID_CLIENTE_B,
    "email": "cliente.b@email.com",
    "display_name": "Carla Paz Test (CBBA)",
    "phone": "+59165432109",
    "user_role": "Cliente",
    "created_at": now,
  },
  {
    "uid": UID_PROPIETARIO_C,
    "email": "propietario.c@app.com",
    "display_name": "Inmobiliaria La Paz",
    "phone": "+59177788899",
    "user_role": "Propietario",
    "created_at": now,
  },
  {
    "uid": UID_CLIENTE_D,
    "email": "cliente.d@email.com",
    "display_name": "Juan Pérez",
    "phone": "+59160001112",
    "user_role": "Cliente",
    "created_at": now,
  },
];

final List<Map<String, dynamic>> testProperties = [
  // 1. Venta - Casa Lujo (SCZ)
  {
    "owner_id": UID_PROPIETARIO_A,
    "title": "Casa de Lujo con Piscina en Equipetrol",
    "description": "Residencia moderna cerca del Ventura Mall. Totalmente equipada.",
    "transaction_type": "venta",
    "property_type": "casa",
    "price": 350000,
    "currency": "USD",
    "area_sqm": 450,
    "rooms": 4,
    "bathrooms": 5,
    "department": "Santa Cruz",
    "zone_key": "equipetrol_norte",
    "amenities": {
      "piscina": true,
      "parrillero": true,
      "aire_acondicionado": true,
    },
    "geopoint": const GeoPoint(-17.7834, -63.1821),
    "is_active": true,
    "created_at": now,
  },
  // 2. Anticrético - Depto Económico (CBBA)
  {
    "owner_id": UID_CLIENTE_B,
    "title": "Departamento en Anticrético, Zona Norte CBBA",
    "description": "Excelente oportunidad cerca del IC Norte. Bajo costo y listo para habitar.",
    "transaction_type": "anticretico",
    "property_type": "departamento",
    "price": 40000,
    "currency": "USD",
    "area_sqm": 95,
    "rooms": 2,
    "bathrooms": 2,
    "department": "Cochabamba",
    "zone_key": "zona_norte_cbba",
    "amenities": {"ascensor": true, "calefaccion": false, "parqueo": true},
    "geopoint": const GeoPoint(-17.3888, -66.1557),
    "is_active": true,
    "created_at": now,
  },
  // 3. Alquiler - Oficina (La Paz)
  {
    "owner_id": UID_PROPIETARIO_C,
    "title": "Oficina Amoblada con Vista en Sopocachi",
    "description": "Edificio corporativo, incluye servicios e internet.",
    "transaction_type": "alquiler",
    "property_type": "oficina",
    "price": 650,
    "currency": "USD",
    "area_sqm": 70,
    "rooms": 0,
    "bathrooms": 1,
    "department": "La Paz",
    "zone_key": "sopocachi",
    "amenities": {"internet": true, "seguridad_24h": true, "ascensor": true},
    "geopoint": const GeoPoint(-16.5167, -68.1250),
    "is_active": true,
    "created_at": now,
  },
  // 4. Venta - Mini Depto (SCZ)
  {
    "owner_id": UID_PROPIETARIO_A,
    "title": "Mini Departamento Ideal para Inversión",
    "description": "Bajo precio, alta rentabilidad. A pasos del 2do Anillo.",
    "transaction_type": "venta",
    "property_type": "departamento",
    "price": 55000,
    "currency": "USD",
    "area_sqm": 60,
    "rooms": 1,
    "bathrooms": 1,
    "department": "Santa Cruz",
    "zone_key": "zona_sur_scz",
    "amenities": {"ascensor": false, "parrillero": false, "amueblado": false},
    "geopoint": const GeoPoint(-17.8100, -63.1700),
    "is_active": true,
    "created_at": now,
  },
  // 5. Alquiler - Casa (CBBA)
  {
    "owner_id": UID_CLIENTE_B,
    "title": "Hermosa Casa en Alquiler en Colcapirhua",
    "description": "Espaciosa y con jardín, perfecta para niños y mascotas.",
    "transaction_type": "alquiler",
    "property_type": "casa",
    "price": 2500,
    "currency": "BOB",
    "area_sqm": 150,
    "rooms": 3,
    "bathrooms": 2,
    "department": "Cochabamba",
    "zone_key": "colcapirhua",
    "amenities": {"garaje": true, "jardin": true, "pet_friendly": true},
    "geopoint": const GeoPoint(-17.3700, -66.2500),
    "is_active": true,
    "created_at": now,
  },
  // 6. Anticrético - Depto 3 Dorm (La Paz)
  {
    "owner_id": UID_PROPIETARIO_C,
    "title": "Anticrético 3 Dormitorios en Miraflores",
    "description": "Cerca del Hospital Obrero. Incluye depósito y servicios.",
    "transaction_type": "anticretico",
    "property_type": "departamento",
    "price": 50000,
    "currency": "USD",
    "area_sqm": 120,
    "rooms": 3,
    "bathrooms": 2,
    "department": "La Paz",
    "zone_key": "miraflores",
    "amenities": {"deposito": true, "gas_domiciliario": true, "ascensor": true},
    "geopoint": const GeoPoint(-16.5000, -68.1200),
    "is_active": true,
    "created_at": now,
  },
  // 7. Venta - Terreno (SCZ, Warnes)
  {
    "owner_id": UID_PROPIETARIO_A,
    "title": "Terreno Industrial/Residencial en Warnes",
    "description": "Documentos al día, ideal para construir o invertir.",
    "transaction_type": "venta",
    "property_type": "terreno",
    "price": 32000,
    "currency": "USD",
    "area_sqm": 500,
    "rooms": 0,
    "bathrooms": 0,
    "department": "Santa Cruz",
    "zone_key": "warnes",
    "amenities": {"agua": true, "electricidad": true},
    "geopoint": const GeoPoint(-17.5000, -63.1500),
    "is_active": true,
    "created_at": now,
  },
  // 8. Alquiler - Local Comercial (SCZ)
  {
    "owner_id": UID_PROPIETARIO_C,
    "title": "Local Comercial en Esquina Central",
    "description": "Alto flujo peatonal y vehicular, excelente visibilidad.",
    "transaction_type": "alquiler",
    "property_type": "local_comercial",
    "price": 1200,
    "currency": "USD",
    "area_sqm": 110,
    "rooms": 0,
    "bathrooms": 2,
    "department": "Santa Cruz",
    "zone_key": "zona_central_scz",
    "amenities": {"deposito": true, "parqueo_clientes": true, "alarma": true},
    "geopoint": const GeoPoint(-17.7900, -63.1950),
    "is_active": true,
    "created_at": now,
  },
  // 9. Venta - Departamento Nuevo (CBBA)
  {
    "owner_id": UID_PROPIETARIO_A,
    "title": "Departamento Nuevo a Estrenar con Amenities",
    "description": "Edificio moderno con salón de eventos y seguridad.",
    "transaction_type": "venta",
    "property_type": "departamento",
    "price": 105000,
    "currency": "USD",
    "area_sqm": 130,
    "rooms": 3,
    "bathrooms": 3,
    "department": "Cochabamba",
    "zone_key": "zona_norte_cbba",
    "amenities": {"piscina": true, "ascensor": true, "parrillero": true},
    "geopoint": const GeoPoint(-17.3750, -66.1600),
    "is_active": true,
    "created_at": now,
  },
  // 10. Anticrético - Casa (La Paz)
  {
    "owner_id": UID_CLIENTE_B,
    "title": "Casa en Anticrético Zona La Florida",
    "description": "Amplia y soleada, excelente zona residencial.",
    "transaction_type": "anticretico",
    "property_type": "casa",
    "price": 60000,
    "currency": "USD",
    "area_sqm": 220,
    "rooms": 5,
    "bathrooms": 4,
    "department": "La Paz",
    "zone_key": "la_florida",
    "amenities": {"jardin": true, "garaje": true, "calefaccion": true},
    "geopoint": const GeoPoint(-16.5300, -68.0800),
    "is_active": true,
    "created_at": now,
  },
];

final Map<String, dynamic> testCatalogs = {
  "regions": {
    "departments": ["Cochabamba", "La Paz", "Santa Cruz", "Tarija", "Oruro"],
    "zones_cochabamba": [
      "Zona Norte CBBA",
      "Colcapirhua",
      "Sacaba",
      "Quillacollo",
    ],
    "zones_santa_cruz": [
      "Equipetrol Norte",
      "Urubó",
      "Urbari",
      "Zona Sur SCZ",
      "Warnes",
      "Zona Central SCZ",
    ],
    "zones_la_paz": ["Sopocachi", "Miraflores", "La Florida", "San Pedro"],
  },
  "filters": {
    "property_types": [
      "casa",
      "departamento",
      "terreno",
      "oficina",
      "local_comercial",
    ],
    "amenities_master": [
      "piscina",
      "parrillero",
      "ascensor",
      "calefaccion",
      "amueblado",
      "jardin",
      "seguridad_24h",
      "internet",
      "deposito",
      "parqueo",
      "pet_friendly",
      "agua",
      "electricidad",
    ],
  },
};

Future<String> seedDatabase() async {
  try {
    final batch = _firestore.batch();

    // 1. Insertar usuarios de prueba
    for (var user in testUsers) {
      batch.set(_firestore.collection('users').doc(user['uid']), user);
    }

    // 2. Insertar propiedades
    for (var property in testProperties) {
      final docRef = _firestore.collection('properties').doc();
      batch.set(docRef, property);
    }

    // 3. Insertar catálogos
    batch.set(
      _firestore.collection('catalogs').doc('regions'),
      testCatalogs['regions'],
    );
    batch.set(
      _firestore.collection('catalogs').doc('filters'),
      testCatalogs['filters'],
    );

    await batch.commit();
    return 'Base de datos inicializada con ${testProperties.length} propiedades disponibles para todos los usuarios.';
  } catch (e) {
    return 'Error al inicializar la base de datos: $e';
  }
}
