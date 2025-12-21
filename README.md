# IoT Pulse System - Architecture & Workflow

<div dir="rtl">

* **سير عمل النظام:** يبدأ النظام بمسح حساسات النبض (BLE) عبر Flutter، استخراج البيانات، وإرسالها إلى NestJS REST API للتخزين.
* **بنية الباك إيند:** سيرفر NestJS منظم يعتمد على Services لحفظ البيانات و Controllers لتوفير نقاط اتصال برمجية (Endpoints).
* **منطق الموبايل:** تطبيق Flutter يستخدم مكتبة `flutter_blue_plus` لاكتشاف الأجهزة ومكتبة `http` للمزامنة مع الباك إيند.
* **بروتوكول الاتصال:** يعتمد على Bluetooth Low Energy للحساسات المحلية وبروتوكول HTTP/JSON للاتصال بالسيرفر.
* **هدف الربط:** استعراض حلقة IoT متكاملة: هاردوير (محاكي) -> بوابة موبايل -> سيرفر سحابي/محلي.

</div>

---

* **System Workflow:** The system starts by scanning for BLE pulse sensors via Flutter, extracting data, and pushing it to a NestJS REST API for storage.
* **Backend Architecture:** A modular NestJS server using Services for data persistence and Controllers to expose endpoints (`POST /readings`, `GET /readings/latest`).
* **Mobile Logic:** Built with Flutter using `flutter_blue_plus` for device discovery and the `http` package for backend synchronization.
* **Communication Protocol:** Uses Bluetooth Low Energy (BLE) for local sensing and HTTP/JSON for remote server communication.
* **Integration Goal:** Demonstrating a full-stack IoT loop: Hardware (Simulated) -> Mobile Gateway -> Cloud/Local Server.