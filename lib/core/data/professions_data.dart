import '../models/profession_category.dart';

const List<ProfessionCategory> professionsData = [
  ProfessionCategory(
    category: 'Mano de obra',
    subcategories: [
      'Electricista',
      'Plomero',
      'Albañil',
      'Carpintero',
      'Pintor',
      'Soldador',
    ],
  ),
  ProfessionCategory(
    category: 'Técnicos',
    subcategories: [
      'Técnico en refrigeración',
      'Técnico en computadoras',
      'Técnico automotriz',
      'Técnico en electrodomésticos',
      'Técnico en audio/video',
    ],
  ),
  ProfessionCategory(
    category: 'Profesionales',
    subcategories: [
      'Desarrollador web',
      'Desarrollador mobile',
      'Diseñador UX/UI',
      'Diseñador gráfico',
      'Arquitecto',
      'Ingeniero civil',
      'Contador',
      'Abogado',
    ],
  ),
  ProfessionCategory(
    category: 'Otros',
    subcategories: [
      'Jardinero',
      'Limpieza',
      'Mudanzas',
      'Seguridad',
      'Chef/Cocinero',
      'Fotógrafo',
      'Músico',
    ],
  ),
];
