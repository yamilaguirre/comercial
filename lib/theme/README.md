# Sistema de Tema - Documentación

## 📁 Estructura

```
lib/theme/
├── theme.dart              # Barrel file - punto de entrada único
├── app_theme.dart          # Configuración principal del ThemeData
├── styles.dart             # Colores, gradientes, sombras y constantes
├── text_styles.dart        # Estilos de tipografía reutilizables
└── component_themes.dart   # Decoraciones para componentes específicos
```

## 🎨 Uso

### Import único

```dart
import 'package:my_first_app/theme/theme.dart';
```

### Colores

```dart
// Colores primarios
Styles.primaryColor      // #4B00FF - Púrpura principal
Styles.primaryAlt        // #7A3BFF - Púrpura claro
Styles.accentColor       // #FF6B35 - Naranja (CTAs)

// Colores neutros
Styles.neutralLight      // Fondos claros
Styles.neutralMedium     // Bordes
Styles.borderColor       // Divisores

// Colores de texto
Styles.textPrimary
Styles.textSecondary
Styles.textDisabled
```

### Gradientes

```dart
// Gradiente horizontal para botones/cards
Container(
  decoration: BoxDecoration(
    gradient: Styles.primaryGradient,
  ),
)

// Gradiente de fondo personalizable
Container(
  decoration: BoxDecoration(
    gradient: Styles.backgroundGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
)
```

### Espaciado

```dart
Styles.spacingXSmall    // 4.0
Styles.spacingSmall     // 8.0
Styles.spacingMedium    // 16.0
Styles.spacingLarge     // 24.0
Styles.spacingXLarge    // 32.0
```

### Bordes Redondeados

```dart
Styles.radiusSmall      // 8.0
Styles.radiusMedium     // 12.0
Styles.radiusLarge      // 16.0
Styles.radiusXLarge     // 24.0
```

### Tipografía

```dart
Text('Título', style: TextStyles.title)
Text('Subtítulo', style: TextStyles.subtitle)
Text('Cuerpo', style: TextStyles.body)
Text('Pequeño', style: TextStyles.caption)
Text('Botón', style: TextStyles.button)
Text('Link', style: TextStyles.link)
Text('Badge', style: TextStyles.badge)
Text('Precio', style: TextStyles.price)
```

### Decoraciones de Componentes

```dart
// Cards
Card(
  elevation: ComponentThemes.cardTheme.elevation,
  shape: ComponentThemes.cardTheme.shape,
)

// Cajas de información
Container(
  decoration: ComponentThemes.infoBoxDecoration(),  // Azul
  decoration: ComponentThemes.errorBoxDecoration(), // Rojo
  decoration: ComponentThemes.successBoxDecoration(), // Verde
  decoration: ComponentThemes.warningBoxDecoration(), // Naranja
)

// Badges
Container(
  decoration: ComponentThemes.badgeDecoration(color: Styles.primaryAlt),
)

// Divisores
Container(
  decoration: BoxDecoration(
    border: ComponentThemes.bottomBorder(),
  ),
)
```

## ✨ Ventajas

- **Consistencia**: Todos los colores y estilos en un solo lugar
- **Mantenibilidad**: Cambios globales editando un solo archivo
- **Escalabilidad**: Fácil añadir nuevos estilos y componentes
- **Type-safe**: Aprovecha el sistema de tipos de Dart
- **DRY**: No repetir valores hardcodeados
- **Documentado**: Comentarios claros en cada constante

## 🔄 Migración

### Antes

```dart
Container(
  color: Color(0xFF4B00FF),
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
  ),
)
```

### Después

```dart
Container(
  color: Styles.primaryColor,
  padding: EdgeInsets.all(Styles.spacingMedium),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(Styles.radiusMedium),
  ),
)
```

## 📝 Checklist de Refactorización

- [ ] Reemplazar todos los `Color(0x...)` hardcodeados
- [ ] Usar `Styles.spacing*` en lugar de números mágicos
- [ ] Usar `Styles.radius*` para `BorderRadius`
- [ ] Reemplazar `TextStyle` inline por `TextStyles.*`
- [ ] Usar `ComponentThemes` para decoraciones repetidas
- [ ] Importar `theme.dart` en lugar de múltiples archivos

## 🎯 Próximos Pasos

1. Terminar de migrar todas las pantallas a usar el theme
2. Añadir modo oscuro (DarkTheme)
3. Crear variantes de colores para estados (hover, pressed, disabled)
4. Añadir animaciones y transiciones predeterminadas
5. Documentar componentes personalizados
