# Habit Tracker App 🥦🔥

A minimalist Flutter + Firebase app to help you build consistent daily habits — inspired by Duolingo’s streak and reward system.

This app helps you log and track two simple habits:
- 🥦 Eat Vegetables before coming home from work
- 🚶 Go for a short walk

It’s designed for gentle, motivating habit-building with streak tracking, rewards, and visual feedback.

---

## Features

✅ Log daily habits with one tap  
✅ Track streaks per habit (Duolingo-style)  
✅ Disable buttons once logged for the day  
✅ Pop-up reward messages at key streak milestones (e.g. 7, 30 days)  
✅ Firebase Firestore backend (fully synced)  
✅ Web support + Android-ready

---

## Screenshots (Coming Soon)

---

## Getting Started

### 🚀 Prerequisites
- Flutter SDK installed (>= 3.x)
- Firebase project created
- A `firebase_options.dart` file configured (you can use `flutterfire configure` or add it manually)

### 🛠 Run the App
```bash
flutter pub get
flutter run -d chrome  # or -d android
```

### 🔐 Firebase Setup (Quick)
- Enable Firestore in your Firebase console
- Create a Web app and copy its config into `firebase_options.dart`
- Set Firestore rules to test mode for dev:
```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

---

## Project Structure
```text
/lib
  main.dart            # Main app UI & logic
  firebase_options.dart  # Firebase config (not checked into Git)
```

---

## Roadmap / Ideas
- ❄️ Add Freeze Tokens to preserve streaks
- 🔔 Local notification reminders
- 📅 Calendar view of completions
- 📈 Progress dashboard
- 👤 Firebase Auth for multiple users

---

## License
MIT © 2024
