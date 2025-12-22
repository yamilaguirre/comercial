// Este archivo sirve como un diccionario local para el formulario de propiedades
// Basado en tu colección 'catalogs/filters' y la estructura de 'properties'.

class PropertyConstants {
  // Tipos de Transacción (Basado en transaction_type)
  static const List<String> transactionTypes = [
    'sale', // Venta
    'rent', // Alquiler
    'anticretico', // Anticrético
  ];

  static String getTransactionTitle(String type) {
    switch (type) {
      case 'sale':
        return 'Venta';
      case 'rent':
        return 'Alquiler';
      case 'anticretico':
        return 'Anticrético';
      default:
        return 'Desconocido';
    }
  }

  // Tipos de Propiedad (Basado en property_types)
  static const List<String> propertyTypes = [
    'casa',
    'departamento',
    'terreno',
    'oficina',
    'local_comercial',
  ];

  static String getPropertyTitle(String type) {
    switch (type) {
      case 'casa':
        return 'Casa';
      case 'departamento':
        return 'Departamento';
      case 'terreno':
        return 'Terreno';
      case 'oficina':
        return 'Oficina';
      case 'local_comercial':
        return 'Local Comercial';
      default:
        return 'Otro';
    }
  }

  // Monedas (Basado en currency)
  static const List<String> currencies = [
    'BS', // Bolivianos (Bs)
    'USD', // Dólares
  ];

  // Amenities (Basado en amenities_master - ¡Usamos las claves de Firebase!)
  static const Map<String, String> amenityLabels = {
    // --- Servicios Básicos ---
    'agua': 'Agua potable',
    'electricidad': 'Electricidad',
    'gas_domiciliario': 'Gas Domiciliario',
    'alcantarillado': 'Alcantarillado',
    'internet': 'Internet / Wifi',

    // --- Climatización ---
    'aire_acondicionado': 'Aire Acondicionado',
    'calefaccion': 'Calefacción',
    'chimenea': 'Chimenea',
    'ventiladores': 'Ventiladores de techo',

    // --- Exteriores y Relax ---
    'piscina': 'Piscina',
    'jacuzzi': 'Jacuzzi',
    'sauna': 'Sauna / Spa',
    'parrillero': 'Parrillero / BBQ',
    'jardin': 'Jardín',
    'terraza': 'Terraza',
    'balcon': 'Balcón',
    'solarium': 'Solarium',

    // --- Áreas Sociales y Deportes ---
    'gimnasio': 'Gimnasio',
    'salon_fiestas': 'Salón de Fiestas',
    'sala_juegos': 'Sala de Juegos',
    'cine': 'Cine / Microcine',
    'cancha_futbol': 'Cancha de Fútbol',
    'cancha_tenis': 'Cancha de Tenis',
    'area_ninos': 'Área de Niños / Playground',

    // --- Trabajo y Tecnología ---
    'coworking': 'Coworking / Oficina',
    'domotica': 'Domótica / Smart Home',
    'acceso_digital': 'Acceso Digital (Huella/Clave)',
    'intercomunicador': 'Intercomunicador',

    // --- Seguridad y Acceso ---
    'seguridad_24': 'Seguridad 24h',
    'camaras': 'Cámaras de Vigilancia',
    'porteria': 'Portería / Recepción',
    'ascensor': 'Ascensor',
    'ascensor_carga': 'Ascensor de Carga',

    // --- Interior y Equipamiento ---
    'amueblado': 'Amueblado',
    'cocina_equipada': 'Cocina Equipada',
    'lavanderia': 'Lavandería',
    'lavavajillas': 'Lavavajillas',
    'deposito': 'Depósito / Baulera',
    'closets': 'Closets Empotrados',

    // --- Estacionamiento y Movilidad ---
    'parqueo': 'Parqueo / Garaje',
    'parqueo_visitas': 'Parqueo de Visitas',
    'carga_autos': 'Carga Autos Eléctricos',
    'bicicletero': 'Bicicletero',

    // --- Estilo de Vida y Accesibilidad ---
    'pet_friendly': 'Pet Friendly',
    'accesibilidad': 'Acceso Discapacitados',
    'vista_panoramica': 'Vista Panorámica',
    'paneles_solares': 'Paneles Solares',
  };
}
