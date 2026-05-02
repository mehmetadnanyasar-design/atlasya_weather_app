# Atlasya Weather - GitHub Build Rehberi

## GitHub'a yüklerken mutlaka gönderilecekler

- `lib/`
- `pubspec.yaml`
- `.github/workflows/build-android.yml`
- `README.md`
- `GITHUB_BUILD_GUIDE.md`

`android/` klasörü zipte yoksa sorun değil. GitHub Actions içinde otomatik oluşturulur.

## APK/AAB alma

1. GitHub repo içinde dosyaları yükle ve `Commit changes` bas.
2. Üst menüden `Actions` sekmesine gir.
3. `Build Android APK and AAB` workflow'una tıkla.
4. Build bitince en alttaki `Artifacts` bölümünden indir:
   - `AtlasyaWeather-release-apk` → telefona kurmak için APK
   - `AtlasyaWeather-playstore-aab` → Play Store için AAB

## .github görünmezse

Windows bazen nokta ile başlayan klasörleri garip gösterebilir. Repo içinde `.github/workflows/build-android.yml` yoksa:

1. Repo'da `Add file > Create new file` seç.
2. Dosya adı olarak şunu yaz:
   `.github/workflows/build-android.yml`
3. Bu zip içindeki `GITHUB_ACTIONS_BACKUP/build-android.yml` dosyasının içeriğini kopyalayıp yapıştır.
4. `Commit changes` bas.
