#!/usr/bin/env bash
# Genera android/ e ios/ (no se versionan carpetas generadas sin cambios) y aplica
# los ajustes necesarios para desarrollo local contra el BFF por HTTP.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create . --project-name kinti --org ec.kinti --platforms=android,ios >/dev/null
echo "✓ Plataformas generadas"

python3 - <<'PY'
import re, pathlib

# Android: permiso de notificaciones (Android 13+) e INTERNET para builds release.
main = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = main.read_text()
for perm in ['android.permission.INTERNET', 'android.permission.POST_NOTIFICATIONS']:
    if perm not in s:
        s = s.replace('<application', f'<uses-permission android:name="{perm}"/>\n    <application', 1)
main.write_text(s)

# Android debug: permite HTTP en claro SOLO en debug (emulador → 10.0.2.2). Release exige HTTPS.
debug = pathlib.Path('android/app/src/debug/AndroidManifest.xml')
d = debug.read_text()
if 'usesCleartextTraffic' not in d:
    d = d.replace('</manifest>', '    <application android:usesCleartextTraffic="true"/>\n</manifest>')
    debug.write_text(d)

# minSdk 23 (firebase_messaging / flutter_secure_storage).
for gradle in [pathlib.Path('android/app/build.gradle.kts'), pathlib.Path('android/app/build.gradle')]:
    if gradle.exists():
        g = gradle.read_text()
        g = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', g)
        g = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', g)
        gradle.write_text(g)

# iOS: permite red local en desarrollo (simulador → localhost) sin desactivar ATS globalmente.
plist = pathlib.Path('ios/Runner/Info.plist')
p = plist.read_text()
if 'NSAppTransportSecurity' not in p:
    p = p.replace('<dict>', '<dict>\n\t<key>NSAppTransportSecurity</key>\n\t<dict>\n\t\t<key>NSAllowsLocalNetworking</key>\n\t\t<true/>\n\t</dict>', 1)
    plist.write_text(p)
print('✓ Manifiestos y Info.plist ajustados')
PY

# iOS 13+ requerido por firebase_messaging.
if [ -f ios/Podfile ]; then
  sed -i.bak "s/^# platform :ios.*/platform :ios, '13.0'/" ios/Podfile && rm -f ios/Podfile.bak
fi

flutter pub get >/dev/null
echo "✓ Listo. Ejecuta: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080"
