# English AI Flutter app

Flutter frontend for the authentication and profile APIs in `../English-AI-main`.

## Run

From this directory:

```powershell
flutter pub get
flutter run
```

Demo mode is enabled by default and works without the backend. Open Connection settings to switch to Live API mode and set the backend URL. Defaults are `http://localhost:5000` for web and desktop, and `http://10.0.2.2:5000` for the Android emulator. For a physical phone, use the computer's LAN IP and ensure both devices can reach each other.

Google sign-in needs a Google OAuth client ID:

```powershell
flutter run --dart-define=GOOGLE_CLIENT_ID=your-client-id
```

## API coverage

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh` and `POST /api/v1/auth/logout`
- `POST /api/v1/auth/forgot-password`, `/verify-otp`, and `/reset-password`
- `POST /api/v1/auth/google`
- `GET`, `PATCH`, and `DELETE /api/v1/users/me`
