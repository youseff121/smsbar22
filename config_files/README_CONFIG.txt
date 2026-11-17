# فایل‌های کانفیگ و آپدیت پیامک‌بار

## 1) روی هاست شخصی
مسیر پیشنهادی:
- https://YOUR_DOMAIN.com/dalahoo/config.json
- https://YOUR_DOMAIN.com/dalahoo/app-release.apk  (فایل APK برای آپدیت)

محتوای config.json را با شماره‌ها و آدرس واقعی خودت ویرایش کن.

## 2) روی GitHub
1. یک ریپوی عمومی یا فایل در ریپوی فعلی بساز
2. فایل config.json را در ریشه (یا مسیر دلخواه) بگذار
3. آدرس raw را در sources بگذار، مثال:
   https://raw.githubusercontent.com/USER/REPO/main/config.json

## فیلدها
- senders: شماره‌های فرستنده مجاز (ترجیحاً با 98)
- destinations: شماره/شماره‌های گیرنده برای فوروارد
- sources: لیست URLهایی که اپ برای خواندن کانفیگ امتحان می‌کند
- app.version: نسخه جدید (باید با versionName+versionCode اپ یکی باشد، مثل 1.0.2+3)
- app.url: لینک مستقیم دانلود APK (حتماً https)

## نکته
بعد از تغییر config.json روی هاست/گیت‌هاب، اپ در اجرای بعدی با RemoteConfigService.refresh() آن را می‌خواند.
