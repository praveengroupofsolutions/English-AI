# English AI

This repository contains the Express API and the Flutter client.

## Repository layout

- `src/` and root `package.json`: Express backend
- `frontend/`: Flutter app for Android, iOS, and web
- `scripts/`: backend utilities

Open `D:\English-AI-main-push` in VS Code. The ZIP folder `D:\English-AI-main` has no Git history, so Git commands must run in this cloned repository.

## Run the backend

In PowerShell terminal 1:

```powershell
cd D:\English-AI-main-push
npm install
```

Create a private `.env` file in the repository root. Do not commit it. Configure at least:

```text
PORT=5000
MONGODB_URI=<your MongoDB connection string>
JWT_ACCESS_SECRET=<a long random secret>
JWT_REFRESH_SECRET=<a different long random secret>
```

For email-based password reset, also configure `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, and optionally `SMTP_FROM`. Google sign-in requires `GOOGLE_CLIENT_ID`. Then start the API:

```powershell
npm run dev
```

The API listens on `http://localhost:5000` by default.

## Run the Flutter app

In PowerShell terminal 2:

```powershell
cd D:\English-AI-main-push\frontend
flutter pub get
flutter run
```

Choose an Android emulator, connected device, or web device when prompted. In the app's connection settings, use `http://10.0.2.2:5000` for the Android emulator, `http://localhost:5000` for web/iOS simulator, or your computer's LAN IP for a physical phone. Demo mode works without the backend.

## Sync with GitHub

Before starting work, open the cloned repository and update your local `main`:

```powershell
cd D:\English-AI-main-push
git switch main
git pull --rebase origin main
git status
```

If `git status` shows your own uncommitted changes, commit or stash them before pulling. Do not pull from the ZIP folder; it has no `.git` directory.

After editing frontend, backend, or both:

```powershell
git status
git add .
git diff --cached --stat
git diff --cached
git commit -m "Describe your change"
git push origin main
```

Review the staged diff before committing. `.env`, dependencies, Flutter build output, and local machine settings are ignored. Never use `git push --force` to resolve a rejected push.

If someone else pushed while you were working, first commit your changes, then sync and push:

```powershell
git pull --rebase origin main
git push origin main
```

If Git reports a conflict, resolve the marked files, then run `git add <resolved-file>` and `git rebase --continue`; after the rebase completes, run `git push origin main`.
