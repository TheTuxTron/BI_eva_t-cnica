# Design system y paleta

## Identidad de marca

La paleta parte de la identidad visual actual de **Banco Internacional**: el naranja de su logotipo, el café oscuro del texto que lo acompaña y un durazno claro presente en sus aplicaciones sobre fondo naranja.

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


## Personalización dentro de la marca

El servidor envía el segmento y la app aplica una expresión distinta **sin salir de la paleta** (`KBrand.forSegment`):

| Segmento | Tarjeta de saldo | Color de acción |
|---|---|---|
| Joven | Degradé naranja → naranja claro, texto oscuro | Naranja texto |
| Clásico | Naranja sólido, texto oscuro | Naranja texto |
| Premium | Degradé café profundo, texto blanco, acento naranja | Café |

## Componentes base

`KCard`, `AmountText` (cifras tabulares, lectura para lectores de pantalla, modo oculto), `Skeleton` (respeta "reducir movimiento"), `ErrorView` y `FailureText` (con código de soporte y detalle técnico solo en debug), `StaleNotice`, `LoadingButton`, `KintiLogo` y `kInput`.
