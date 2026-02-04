# 🚀 Paqet Easy Installer (Server)

نصب خودکار، سریع و اصولی **Paqet Server** روی لینوکس  
با تمرکز روی پایداری، رفتار شبکه‌ای طبیعی و حداقل دخالت دستی 🧠🕶️

این پروژه یک **Bash Installer** تمیز و مرحله‌بندی‌شده است که Paqet را به‌صورت Server  
با تنظیمات پیشنهادی و مناسب محیط‌های واقعی (VPS / Dedicated) راه‌اندازی می‌کند.

---

## ✨ ویژگی‌ها

✅ اجرای یک‌خطی (One-Line Install)  
✅ تشخیص خودکار کارت شبکه، Gateway و MAC  
✅ دریافت آخرین Release رسمی Paqet از GitHub  
✅ ساخت خودکار فایل کانفیگ با تنظیمات امن و پیشنهادی  
✅ جلوگیری از دخالت کرنل با iptables (NOTRACK + RST drop)  
✅ غیرفعال‌سازی Offloading کارت شبکه (GRO / GSO / TSO)  
✅ اجرای دائمی با systemd  
✅ لاگ‌های رنگی، خوانا و مرحله‌بندی‌شده  
✅ بدون وابستگی به Docker یا ابزارهای جانبی

---

## 🧠 Paqet چیست؟

**Paqet** یک ابزار تونلینگ سطح پایین (Low-Level Packet Tunneling) است که  
با کنترل مستقیم روی نحوه‌ی ارسال پکت‌ها، ترافیکی شبیه TCP واقعی تولید می‌کند  
و از الگوهای ساده و قابل شناسایی فاصله می‌گیرد.

این اسکریپت Paqet را در حالت **Server Mode** و با تنظیمات پیشنهادی نسخه‌های جدید راه‌اندازی می‌کند.

---

## ⚡ نصب سریع (One-Line Command)

کافی است دستور زیر را روی سرور اجرا کنید:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/radiolemonatic/paqet-easy-installer/main/install.sh)
