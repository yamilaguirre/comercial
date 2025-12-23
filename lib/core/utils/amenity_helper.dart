import 'package:flutter/material.dart';

class AmenityHelper {
  /// Definición de Categorías y sus claves asociadas.
  /// Esto centraliza el orden y la agrupación de las amenidades.
  static const Map<String, List<String>> amenityCategories = {
    'Servicios Básicos': [
      'agua',
      'electricidad',
      'gas_domiciliario',
      'alcantarillado',
      'internet',
    ],
    'Climatización': [
      'aire_acondicionado',
      'calefaccion',
      'chimenea',
      'ventiladores',
    ],
    'Exteriores & Vistas': [
      'piscina',
      'jardin',
      'terraza',
      'balcon',
      'solarium',
      'vista_panoramica',
      'vista_mar',
    ],
    'Social & Entretenimiento': [
      'parrillero',
      'gimnasio',
      'salon_fiestas',
      'sala_juegos',
      'cine',
      'area_ninos',
      'biblioteca',
    ],
    'Seguridad & Acceso': [
      'seguridad_24',
      'camaras',
      'porteria',
      'intercomunicador',
      'acceso_digital',
      'ascensor',
      'ascensor_carga',
    ],
    'Interior & Equipamiento': [
      'amueblado',
      'cocina_equipada',
      'lavanderia',
      'lavavajillas',
      'deposito',
      'closets',
      'jacuzzi',
      'sauna',
    ],
    'Estacionamiento & Movilidad': [
      'parqueo',
      'parqueo_visitas',
      'carga_autos',
      'bicicletero',
    ],
    'Tecnología & Otros': [
      'coworking',
      'domotica',
      'paneles_solares',
      'pet_friendly',
      'accesibilidad',
    ],
  };

  /// Obtiene el icono general para una CATEGORÍA completa.
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Servicios Básicos':
        return Icons.flash_on;
      case 'Climatización':
        return Icons.thermostat;
      case 'Exteriores & Vistas':
        return Icons.deck;
      case 'Social & Entretenimiento':
        return Icons.celebration;
      case 'Seguridad & Acceso':
        return Icons.security;
      case 'Interior & Equipamiento':
        return Icons.chair;
      case 'Estacionamiento & Movilidad':
        return Icons.directions_car;
      case 'Tecnología & Otros':
        return Icons.smart_toy;
      default:
        return Icons.grid_view;
    }
  }

  /// Obtiene el color para una amenidad específica.
  static Color getAmenityColor(String key) {
    final normalizedKey = key.toLowerCase().trim();
    
    // Servicios Básicos - Azul
    if (normalizedKey.contains('agua') || normalizedKey.contains('electricidad') || 
        normalizedKey.contains('gas') || normalizedKey.contains('internet')) {
      return const Color(0xFF1976D2);
    }
    
    // Climatización - Naranja
    if (normalizedKey.contains('aire') || normalizedKey.contains('calefaccion') || 
        normalizedKey.contains('chimenea')) {
      return const Color(0xFFFF9800);
    }
    
    // Exteriores - Verde
    if (normalizedKey.contains('piscina') || normalizedKey.contains('jardin') || 
        normalizedKey.contains('terraza') || normalizedKey.contains('balcon')) {
      return const Color(0xFF4CAF50);
    }
    
    // Seguridad - Rojo
    if (normalizedKey.contains('seguridad') || normalizedKey.contains('camara') || 
        normalizedKey.contains('portero')) {
      return const Color(0xFFF44336);
    }
    
    // Default - Gris
    return const Color(0xFF757575);
  }

  /// Obtiene el icono para una amenidad específica (alias para getIcon).
  static IconData getAmenityIcon(String key) {
    return getIcon(key);
  }

  /// Obtiene el icono individual para una AMENIDAD específica.
  static IconData getIcon(String key) {
    final normalizedKey = key.toLowerCase().trim();

    // --- 1. SERVICIOS BÁSICOS ---
    if (normalizedKey.contains('wifi') || normalizedKey.contains('internet'))
      return Icons.wifi;
    if (normalizedKey.contains('agua')) return Icons.water_drop;
    if (normalizedKey.contains('luz') || normalizedKey.contains('electricidad'))
      return Icons.flash_on;
    if (normalizedKey.contains('gas')) return Icons.local_fire_department;
    if (normalizedKey.contains('alcantarillado')) return Icons.water_damage;

    // --- 2. CLIMATIZACIÓN ---
    if (normalizedKey.contains('aire') || normalizedKey.contains('a/c'))
      return Icons.ac_unit;
    if (normalizedKey.contains('calefaccion') ||
        normalizedKey.contains('estufa'))
      return Icons.thermostat;
    if (normalizedKey.contains('chimenea')) return Icons.fireplace;
    if (normalizedKey.contains('ventilador')) return Icons.wind_power;

    // --- 3. EXTERIORES Y RECREACIÓN (AGUA) ---
    if (normalizedKey.contains('piscina') || normalizedKey.contains('alberca'))
      return Icons.pool;
    if (normalizedKey.contains('jacuzzi')) return Icons.hot_tub;
    if (normalizedKey.contains('sauna') || normalizedKey.contains('spa'))
      return Icons.spa;

    // --- 4. ÁREAS VERDES Y SOCIALES ---
    if (normalizedKey.contains('jardin') || normalizedKey.contains('patio'))
      return Icons.yard;
    if (normalizedKey.contains('parrillero') || normalizedKey.contains('bbq'))
      return Icons.outdoor_grill;
    if (normalizedKey.contains('terraza') || normalizedKey.contains('balcon'))
      return Icons.balcony;
    if (normalizedKey.contains('solarium')) return Icons.wb_sunny;

    // --- 5. DEPORTES Y ENTRETENIMIENTO ---
    if (normalizedKey.contains('gimnasio') || normalizedKey.contains('gym'))
      return Icons.fitness_center;
    if (normalizedKey.contains('tenis') || normalizedKey.contains('padel'))
      return Icons.sports_tennis;
    if (normalizedKey.contains('futbol')) return Icons.sports_soccer;
    if (normalizedKey.contains('juegos') || normalizedKey.contains('billar'))
      return Icons.sports_esports;
    if (normalizedKey.contains('cine')) return Icons.movie;
    if (normalizedKey.contains('fiestas') || normalizedKey.contains('eventos'))
      return Icons.celebration;

    // --- 6. ESTACIONAMIENTO ---
    if (normalizedKey.contains('parqueo') || normalizedKey.contains('garaje'))
      return Icons.directions_car;
    if (normalizedKey.contains('eléctrico') || normalizedKey.contains('carga'))
      return Icons.ev_station;
    if (normalizedKey.contains('biciclet')) return Icons.pedal_bike;

    // --- 7. SEGURIDAD Y ACCESO ---
    if (normalizedKey.contains('seguridad') || normalizedKey.contains('camara'))
      return Icons.security;
    if (normalizedKey.contains('alarma')) return Icons.alarm;
    if (normalizedKey.contains('portero') ||
        normalizedKey.contains('recepcion'))
      return Icons.person_pin;
    if (normalizedKey.contains('intercomunicador')) return Icons.phone_in_talk;
    if (normalizedKey.contains('digital')) return Icons.fingerprint;

    // --- 8. INTERIORES Y EQUIPAMIENTO ---
    if (normalizedKey.contains('amueblado') ||
        normalizedKey.contains('muebles'))
      return Icons.chair;
    if (normalizedKey.contains('ascensor')) return Icons.elevator;
    if (normalizedKey.contains('lavanderia'))
      return Icons.local_laundry_service;
    if (normalizedKey.contains('cocina')) return Icons.kitchen;
    //if (normalizedKey.contains('lavavajillas')) return Icons.dishwasher_gen;
    if (normalizedKey.contains('baulera') || normalizedKey.contains('deposito'))
      return Icons.warehouse;
    if (normalizedKey.contains('closet')) return Icons.door_sliding;

    // --- 9. VARIOS ---
    if (normalizedKey.contains('mascota') || normalizedKey.contains('pet'))
      return Icons.pets;
    if (normalizedKey.contains('accesibilidad') ||
        normalizedKey.contains('discapacitados'))
      return Icons.accessible;
    if (normalizedKey.contains('coworking') ||
        normalizedKey.contains('oficina'))
      return Icons.work;
    if (normalizedKey.contains('ninos') || normalizedKey.contains('infantil'))
      return Icons.child_care;
    /* if (normalizedKey.contains('domotica') || normalizedKey.contains('smart'))
      return Icons.smart_home; */
    if (normalizedKey.contains('solar')) return Icons.solar_power;
    if (normalizedKey.contains('vista')) return Icons.panorama;
    if (normalizedKey.contains('biblioteca')) return Icons.menu_book;

    // Fallback
    return Icons.check_circle_outline;
  }
}
