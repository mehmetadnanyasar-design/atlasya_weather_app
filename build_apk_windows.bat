@echo off
flutter create --platforms=android .
flutter pub get
flutter build apk --release
pause
