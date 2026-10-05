# Design system y paleta

## Identidad de marca

La paleta parte de la identidad visual actual de **Banco Internacional (Ecuador)**: el naranja de su logotipo, el café oscuro del texto que lo acompaña y un durazno claro presente en sus aplicaciones sobre fondo naranja. Los valores se tomaron de análisis públicos del logotipo (whatthelogo.com: versión actual sobre fondo blanco y sobre fondo naranja). Si el banco comparte su manual de marca oficial, solo hay que ajustar `lib/design_system/tokens.dart` y los temas del BFF.

| Token | Hex | Uso |
|---|---|---|
| `brandOrange` | `#FF8100` | Superficies de marca: tarjeta de saldo, botones primarios, logo. **Siempre con texto oscuro** |
| `brandOrangeLight` | `#FFA347` | Degradé del segmento joven; acción en modo oscuro |
| `brandOrangeText` | `#B85A00` | Texto, enlaces, íconos y bordes de foco naranjas sobre fondo claro |
| `brandCafe` | `#614E4B` | Segundo color de marca: tema premium, banners premium, color secundario |
| `brandCafeDeep` | `#3F322F` | Degradé premium |
| `brandPeach` | `#FFDEBC` | Contenedores suaves: accesos rápidos, íconos, indicador de navegación, celdas del simulador |
| `ink` / `inkMuted` | `#2B2422` / `#6B5D59` | Texto principal y secundario (neutrales cálidos, coherentes con el café) |
| `paper` / `line` | `#F7F5F3` / `#E7DFDA` | Fondo de la app y bordes |
| `positive` / `negative` / `warning` | `#23785A` / `#C8443A` / `#8A5A12` | Semánticos |

## Accesibilidad (WCAG 2.1 AA)

El blanco sobre el naranja de marca tiene un contraste de **2,50:1**, insuficiente incluso para texto grande. Por eso:

| Combinación | Contraste | Cumple |
|---|---|---|
| Tinta `#2B2422` sobre naranja `#FF8100` | 6,09:1 | AA |
| Naranja texto `#B85A00` sobre blanco | 4,67:1 | AA |
| Blanco sobre café `#614E4B` | 7,78:1 | AA |
| Durazno sobre café | 6,08:1 | AA |
| Tinta sobre degradé claro `#FFA347` | 7,68:1 | AA |
| Positivo / negativo / advertencia sobre blanco | 5,38 / 4,83 / 5,91 :1 | AA |

La regla está implementada en el tema: el color sobre el primario se calcula con `ThemeData.estimateBrightnessForColor`, así que es oscuro sobre naranja y blanco sobre café. Los colores interactivos sobre fondos claros salen de `KBrand.action`.

## Personalización dentro de la marca

El servidor envía el segmento y la app aplica una expresión distinta **sin salir de la paleta** (`KBrand.forSegment`):

| Segmento | Tarjeta de saldo | Color de acción |
|---|---|---|
| Joven | Degradé naranja → naranja claro, texto oscuro | Naranja texto |
| Clásico | Naranja sólido, texto oscuro | Naranja texto |
| Premium | Degradé café profundo, texto blanco, acento naranja | Café |

## Componentes base

`KCard`, `AmountText` (cifras tabulares, lectura para lectores de pantalla, modo oculto), `Skeleton` (respeta "reducir movimiento"), `ErrorView` y `FailureText` (con código de soporte y detalle técnico solo en debug), `StaleNotice`, `LoadingButton`, `KintiLogo` y `kInput`.
