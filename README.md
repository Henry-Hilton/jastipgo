# JasTipGo

Flutter jastip application for NRP 160423172, with a PHP 8.1+ / MySQL 8 or MariaDB backend.
The interface uses Indonesian. A single account can switch between Penitip and Jastiper from the navigation drawer.

## Project structure

| Path | Contents |
| --- | --- |
| `lib/` | Flutter screens, API client, session storage and shared widgets |
| `backend/` | PHP endpoints, MySQL schema and example server configuration |
| `assets/fonts/` | Bundled DM Sans font and license |
| `test/` | Flutter tests and the backend acceptance script |
| `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` | Platform runners |

Server credentials, uploaded images, build caches and local submission artifacts are excluded from Git. Create `backend/config.php` from the example when setting up a backend.

## Features

| Final rubric | Implementation | Points |
| --- | --- | --- |
| Authentication and SharedPreferences | Registration, hashed passwords, expiring bearer sessions, auto-login, role switch, logout | 10 |
| Tile catalog and many-to-many categories | Active-trip product grid, combined item/trip/destination/category search | 5 |
| Forms, requests, editing | Trip dates, product inventory, approval/rejection, server-prefilled edits, shopping summary | 20 |
| Images | Camera/gallery bottom sheet, Base64 POST to uploadimage.php, validated PNG storage | 5 |
| Shopping cart | Quantity editing, removal, per-trip order headers and item details, cleared after checkout | 10 |
| Balance | Simple assignment top-up form, payment hold, buyer-confirmed settlement, ledger | 10 |
| GPS tracking | Camera selfie, current GPS, mock-location check where supported, timestamped history, interactive map with 15-second polling | 15 |
| Web service | Authenticated PHP API and relational MySQL schema | 10 |
| Three extra features | Favorites, verified completed-order reviews, activity inbox | 15 |

Orders progress through paid, purchased, delivered and completed. The Jastiper marks purchased and delivered. The Penitip confirms receipt to complete an order and release its balance. These transitions are enforced by the backend.

## Run Flutter

Use Flutter 3.47.5 / Dart 3.13.4 or a compatible newer SDK. Clone the repository, enter its directory, and install dependencies:

```powershell
git clone https://github.com/Henry-Hilton/jastipgo.git
cd jastipgo
flutter pub get
flutter run -d chrome --web-port 8088
```

The compiled default API address is `https://ubaya.fun/flutter/160423172`.
To use the authorized fallback after deploying the same backend and schema there, run

```powershell
flutter run -d chrome --web-port 8088 --dart-define=API_BASE_URL=https://ubaya.fun/flutter/160423155
```

Each server owns its own accounts, balances and orders. Select a server when launching or building the app. Keep requests for a transaction on that selected server.
For a local backend running on port 8091, run

```powershell
flutter run -d chrome --web-port 8088 --dart-define=API_BASE_URL=http://127.0.0.1:8091
```

For Android, install Android SDK command-line tools, Android platform 36, build tools 36 and JDK 17+ compatible with Gradle 9.3.1. Run `flutter doctor` to verify the local toolchain. Android manifest and iOS camera, gallery and foreground-location descriptions are included. Use an Android/iOS device to exercise the native camera and GPS flow. With the generated iOS Swift Package Manager setup, build with `BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ios` to keep location access limited to the foreground. Browser check-in uses the camera support offered by the browser and image_picker. Desktop camera check-in asks the user to use a phone or browser.

## Deploy the backend

The backend is deployed in `/var/www/html/flutter/160423172` on `103.16.116.155`, served at `https://ubaya.fun/flutter/160423172`. Live API acceptance checks passed on November 17, 2026 through an explicit origin-IP connection with TLS certificate verification enabled. Test accounts, transactions and uploaded fixtures were removed afterward. The upload directory grants the PHP service access through a filesystem ACL.

Public DNS for `ubaya.fun` currently returns NXDOMAIN. Ordinary app connections require the course domain to resolve again, or a replacement working HTTPS hostname. The steps below describe setup for a fresh deployment.

1. Import `backend/schema.sql` into the existing student MySQL database. It uses InnoDB and creates its tables without dropping existing data.
2. The observed course nginx configuration maps `/var/www/html/flutter/160423172` to `/flutter/160423172/`. Upload `api.php`, `core.php`, `uploadimage.php`, `image.php` and the `images/` directory from `backend/` into the web directory served at `https://ubaya.fun/flutter/160423172`. Keep the SQL script, configuration example and local router on your development machine. The supplied `.htaccess` files add download restrictions on Apache hosting.
3. Copy `config.example.php` to `config.php` on the server. Fill in the actual database name, username and password. Choose the course timezone if it differs from Asia/Jakarta.
4. Enable PHP PDO MySQL and GD. Allow at least 12 MB POST bodies and a writable `images/` directory owned by the PHP user. GD normalizes accepted JPG/PNG uploads to actual PNG files. Uploaded files use `images/[user_id]/[timestamp]_[random].png`.
5. Serve PHP over HTTPS. Product and check-in images use `image.php`, which supplies CORS headers on nginx and Apache. `config.php` returns its configuration to PHP without printing it.
6. Register two accounts, switch one to Jastiper, create a current trip and a product, then purchase it from the Penitip account. Check each order status and verify that the seller receives funds only after buyer confirmation.

`api.php` accepts POST JSON containing `action` and its arguments. Authenticated calls use `Authorization: Bearer <token>` and `X-Role: penitip` or `jastiper`. `uploadimage.php` accepts the same JSON contract with `action` set to `upload` and an `image` Base64 string. Database credentials may also be supplied with `JASTIPGO_DSN`, `JASTIPGO_DB_USER` and `JASTIPGO_DB_PASSWORD` environment variables.

For a local PHP server, configure `backend/config.php` for a disposable local database and start it with

```powershell
php -S 127.0.0.1:8091 -t backend backend/router.php
```

The local router blocks configuration/SQL access and serves the PHP endpoints. The image endpoint supplies CORS headers independently of web-server configuration.

## Verification

```powershell
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
```

The existing Flutter tests cover form validation, persistent login/role restoration, expired-session cleanup and narrow-screen catalog layout.
The backend test creates unique fixtures and must target a disposable test database. Start two PHP servers sharing that database on ports 8091 and 8092, then run

```powershell
python test/backend_smoke.py --url http://127.0.0.1:8091 --second-url http://127.0.0.1:8092
```

It checks the purchase lifecycle, ownership, invalid inputs, categories, requests, favorites, image upload, GPS records, inbox, reviews, repeat top-up/checkout/completion calls, concurrent purchases of the final unit, and balance conservation. Checkout locks the buyer, trips and products inside a database transaction. Order details preserve the purchased names, prices and quantities. Settlement records a unique ledger entry for each completed order.

## Submission and credits

The submission ZIP uses `JasTipGo_160423172.zip`. Add other group members' NRPs to its filename when applicable. It includes `lib/`, `assets/`, `pubspec.yaml`, the SQL script, backend and platform setup. Confirm the actual ULS deadline with the course.

DM Sans is by Colophon Foundry and contributors, under the SIL Open Font License included in `assets/fonts/OFL.txt`. Map tiles and data are from OpenStreetMap contributors, credited in the tracking view. Flutter Material icons use the Flutter SDK license. Dependencies and their versions are listed in pubspec.yaml and pubspec.lock. Product photos come from user uploads.

The Android scaffold uses the Flutter-generated debug signing configuration for class/demo APKs. Configure a private release signing key before distributing through an app store.
