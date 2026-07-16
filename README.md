# NestlyQuick — Project README
A app that organizes  lists and shares them across users
## Running the App

1. Start your emulator in Android Studio (Device Manager)
2. Open a terminal and navigate to the project:
   ```
   cd C:\Users\Tod\nestlyquick
   ```
3. Run the app:
   ```
   flutter run
   ```

**Useful terminal commands while app is running:**
- `r` — hot reload (applies code changes instantly)
- `R` — hot restart (full restart, use after pubspec.yaml changes)
- `q` — quit

---

## First Time Setup

make sure cd into nestlyquick, flutter run, r R for reloads

---

## Important Notes

- **pubspec.yaml changes** require a full restart — stop with `q` then `flutter run` again
- **Code changes** just need hot reload — press `r` in the terminal
- **Never hardcode colors** — always use `AppColors.whatever` from colors.dart
- **Firebase is set up** — Auth and Firestore connected
- **GoRouter** handles all navigation — don't use Navigator.push directly

---

## Folder Structure

```
nestlyquick/
  lib/
    main.dart
    theme/
      colors.dart
    screens/
      login_screen.dart
      dashboard_screen.dart
      folder_screen.dart
      list_view_screen.dart
      share_list_screen.dart
      notifications_screen.dart
      settings_screen.dart
      edit_profile_screen.dart
    widgets/
      list_card.dart
      item_row.dart
      bottom_sheets/
        add_item_sheet.dart
        create_list_sheet.dart
        edit_list_sheet.dart
        edit_item_sheet.dart
  pubspec.yaml
```

---

## File Index

| File | Location | Purpose |
|---|---|---|
| colors.dart | lib/theme/ | All app colors in one place |
| main.dart | lib/ | App entry point, GoRouter setup, bottom nav shell |
| login_screen.dart | lib/screens/ | Login and signup screen |
| dashboard_screen.dart | lib/screens/ | Lists tab — shows all lists and folders |
| folder_screen.dart | lib/screens/ | Shows lists inside a folder |
| list_view_screen.dart | lib/screens/ | The actual list with items |
| share_list_screen.dart | lib/screens/ | Share list with friends |
| notifications_screen.dart | lib/screens/ | 7 day notification history |
| settings_screen.dart | lib/screens/ | Settings and profile |
| edit_profile_screen.dart | lib/screens/ | Edit name, username, email |
| list_card.dart | lib/widgets/ | Reusable list card component |
| item_row.dart | lib/widgets/ | Reusable item row component |
| add_item_sheet.dart | lib/widgets/bottom_sheets/ | Add item bottom sheet |
| create_list_sheet.dart | lib/widgets/bottom_sheets/ | Create new list bottom sheet |
| edit_list_sheet.dart | lib/widgets/bottom_sheets/ | Edit list name and categories |
| edit_item_sheet.dart | lib/widgets/bottom_sheets/ | Edit existing item |

---

## Navigation Structure (GoRouter)

- **Lists tab** = Dashboard screen (your all lists page)
- Tap a list card → pushes List View on top of dashboard
- Tap a folder card → pushes Folder screen on top of dashboard
- Tap back → returns to dashboard
- Bottom nav always visible except on Login screen

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| go_router | ^14.0.0 | Navigation and routing |
| firebase_core | ^3.0.0 | Required base for all Firebase services |
| firebase_auth | ^5.0.0 | Login, signup, session management |
| cloud_firestore | ^5.0.0 | Firestore cloud database |

---

```dart
FirebaseFirestore.instance.settings = 
  const Settings(persistenceEnabled: true);
```

**Works offline:** viewing lists, checking off items, adding items
**Needs internet:** real time sync, notifications, first load of new data