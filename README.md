# Aura Salud

Aura Salud is a comprehensive mobile application built with Flutter that connects patients with healthcare professionals on-demand. 

## Features

* **Onboarding & User Profiles**: Seamless sign-up and profile management for patients and dependents.
* **Service Requests**: Easily request medical services, including home visits or ambulance services.
* **Active Tracking**: Real-time tracking of active medical appointments and ETA of healthcare professionals.
* **Chat System**: Integrated messaging to communicate securely with assigned medical personnel.
* **Service History**: Keep track of past medical requests, prescriptions, and services.

## Technologies Used

* **Framework**: [Flutter](https://flutter.dev/) (Dart)
* **Backend**: Laravel
* **Design**: Modern Material 3 Design with a custom teal color scheme (`#0D9488`).
* **Dependencies**: `http` for network requests and `intl` for localization/formatting.

## Getting Started

To run this project locally, you will need to run both the Laravel backend and the Flutter frontend.

### 1. Run the Backend (Laravel)

1. **Navigate to the backend directory**:
   ```bash
   cd aura_backend
   ```
2. **Install PHP dependencies** (if you haven't already):
   ```bash
   composer install
   ```
3. **Run the Laravel server**:
   ```bash
   php artisan serve
   ```

### 2. Run the Emulator

1. **List available emulators** to get your emulator ID:
   ```bash
   flutter emulators
   ```
2. **Launch the emulator** (replace `<emulator_id>` with your actual emulator ID):
   ```bash
   flutter emulators --launch <emulator_id>
   ```

### 3. Run the Flutter App

1. **Navigate to the Flutter app directory**:
   ```bash
   cd aura
   ```
2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the app**:
   ```bash
   flutter run
   ```

## Project Structure

* `lib/screens/`: Contains the UI screens for different parts of the application (Home, Chat, Profile, Onboarding, etc.).
* `lib/widgets/`: Reusable UI components like the Custom Bottom Navigation.
* `lib/models/`: Data models representing core entities (e.g., ServiceRequest).
* `lib/state/`: State management logic for the app.
* `lib/data/`: Mock data for testing and development.




# Terminal 1 — backend en HTTP plano
php artisan serve --port=8000

# Terminal 2 — ngrok con tu dominio fijo apuntando al 8000
ngrok http --url=emphatic-ranking-posh.ngrok-free.dev 8000
(Si tu versión de ngrok es antigua, el flag es --domain= en vez de --url=.)

Con eso, https://emphatic-ranking-posh.ngrok-free.dev queda visible desde cualquier red (datos móviles, PC externo), con certificado válido.

Para la APK de prueba (profile o preview):


flutter build apk --profile
# o el debug que ya usas — ambos apuntan solo al ngrok por defecto
No necesitas tocar nada más; si algún día cambias de túnel, flutter build apk --profile --dart-define=API_BASE=https://otro-host/api.

Dos cosas a tener presente
El portal del doctor en el navegador: la primera vez ngrok muestra una pantalla de advertencia "You are about to visit…" — haces clic en Visit Site una vez y listo (la app no la ve porque le pusimos el header).

La videollamada: ngrok arregla el acceso y los POST, pero recuerda que php artisan serve es de un solo hilo. Para uso normal (login, agendar, chat) funciona perfecto. Si al probar la videoconsulta los dos siguen sin verse, ahí sí sería la concurrencia → ese es el momento de RoadRunner/Octane. Vale la pena probar primero sobre ngrok: es posible que el problema anterior fuera el local-ssl-proxy rompiendo los POST, y que ahora ya funcione.
