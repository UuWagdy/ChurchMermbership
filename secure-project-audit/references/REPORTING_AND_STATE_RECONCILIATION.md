# Reporting and State Reconciliation Reference

Use this whenever prior audit reports, “final security status” files, deployment guides, release notes, installers or old builds exist.

## 1. Never trust a report title

A file named “final” may be stale, copied, partially updated or describe planned rather than deployed work. A newer modified timestamp can still contain historical sections. Establish the exact version/commit/environment each claim describes.

## 2. Claim ledger

Create `security/STATE_RECONCILIATION.md` with a table like:

| ID | Security claim | Source and date | Claimed version/commit | Current code evidence | Release/payload evidence | Runtime/deployment evidence | Status | Required action |
|---|---|---|---|---|---|---|---|---|

Allowed statuses:

- `CURRENT`: supported by current code and relevant deployed/release evidence;
- `STALE`: was true for an older version or removed feature;
- `CONTRADICTED`: another stronger source proves the opposite;
- `PARTIAL`: some components/environments differ;
- `UNVERIFIED`: claim exists but no sufficient evidence;
- `PLANNED`: design/guide exists but implementation/deployment does not;
- `NOT APPLICABLE`: feature absent, with evidence.

## 3. Evidence precedence

Use this order while documenting exceptions:

1. observed runtime on the deployed exact artifact;
2. repeatable tests on the exact release build;
3. current code/config/schema at a known commit;
4. installer/payload/package contents and hashes;
5. current operational configuration and deployment records;
6. current documentation;
7. older reports, plans and intentions.

No evidence source alone is perfect. Runtime can be misconfigured, code can be undeployed, and a package can contain stale binaries. Reconcile all three.

## 4. Contradiction rules

- Do not silently merge mutually exclusive claims such as “Google Drive removed” and “Google Drive is active.”
- Identify which modules, platforms, branches or dates each claim belongs to.
- Search current code, dependencies, configuration, screens, OAuth IDs, scheduled workers, installer payload and runtime calls.
- Mark historical sections as historical instead of deleting useful context.
- A rotated key is not proven by a new public key alone; verify old artifacts/history, active key IDs and issuance path.
- “Rules fixed” is not “rules deployed.” Separate code readiness from operational deployment.
- “Tests passed” must state exact commit/build/platform/test count and whether code changed afterward.

## 5. Required owner-facing Arabic final report order

Create `security/FINAL_SECURITY_STATUS_AR.md` in this order:

### 1. الملخص التنفيذي والحكم النهائي

- النطاق، التاريخ، النسخة/الـcommit، البيئات والمنصات.
- `PASS` أو `PASS WITH ACCEPTED RISK` أو `FAIL` مع السبب.
- المخاطر الحرجة/العالية التي تحتاج إجراءً فوريًا.

### 2. الحالة الأصلية ونقطة الرجوع

- الفرع والـcommit الأصليان.
- حالة Git والملفات غير المحفوظة والـremote.
- فرع التقوية.
- أوامر مقارنة ورجوع آمنة بدون `git reset --hard`.

### 3. المعمارية ومصدر الحقيقة

- أين يوجد المنطق البرمجي والمصادقة والتخزين.
- هل النظام Server-authoritative أم Local-authoritative أم Offline-first/Hybrid.
- الفرق بين الكاش والمزامنة والبث اللحظي والنسخ الاحتياطي.
- حدود الثقة وتدفقات البيانات.

### 4. ما تم إصلاحه فعليًا

قسم حسب الحدود:

- التطبيق والمنصات؛
- المصادقة والصلاحيات؛
- Node/Nest/API/WebSocket؛
- PostgreSQL/Redis/الكاش/العمال؛
- SQLite/SQLCipher؛
- المزامنة وتعدد الأجهزة؛
- التفعيل والترخيص؛
- النسخ الاحتياطي والاستعادة؛
- Firebase/Supabase/الويب؛
- Git والأسرار وسلسلة التوريد؛
- المثبت والتسليم.

لا تذكر تحسينًا على أنه منفذ دون diff/test/deployment evidence.

### 5. نتائج Red Team وBlue Team وPurple Team

- الهجمات/الاختبارات التي أثبتت المشكلة.
- السبب الجذري.
- الإصلاح المركزي.
- إعادة الاختبار الأصلية والالتفافات المجاورة.
- الحالة: `RETESTED_FIXED`, `PARTIAL`, `REGRESSED`, `BLOCKED`, `RISK_ACCEPTED`.

### 6. الاختبارات المنفذة بالأرقام

لكل مجموعة:

- الأمر/الأداة والإصدار؛
- عدد الناجح/الفاشل/المتجاوز؛
- المنصة والبيئة؛
- commit/build/hash؛
- ماذا يثبت الاختبار وماذا لا يثبت.

### 7. ما لم يتم اختباره أو كان محجوبًا

- أجهزة أو حسابات أو شهادات أو مفاتيح أو staging غير متاحة.
- اختبارات Runtime أو VM أو LAN أو متجر التطبيقات غير منفذة.
- لا تحول `NOT TESTED` إلى نجاح.

### 8. ما يجب على المالك تنفيذه

رتب بالاعتماد:

1. احتواء/تدوير الأسرار؛
2. نشر القواعد/الخدمات/الإعدادات؛
3. إنشاء مفاتيح التوقيع/OAuth/certificates؛
4. إعادة بناء payload/installer؛
5. اختبار الأجهزة/VM/LAN/restore؛
6. تنظيف النسخ القديمة بعد التحقق؛
7. مراقبة وتشغيل واستجابة للحوادث.

### 9. حدود الحماية الواقعية

- حدود Offline licensing والجهاز المخترق.
- التشفير أثناء تشغيل التطبيق.
- أفضلية الخادم لا تمنع سرقة جلسة صحيحة.
- النسخ الاحتياطي لا يساوي المزامنة.
- البث اللحظي لا يضمن التسليم الدائم.
- ما يحتاج خدمة online أو عتاد موثوق أو إجراءات تشغيلية.

### 10. الجاهزية للإنتاج

- المخاطر المتبقية والمقبولة ومن يملكها وتاريخ مراجعتها.
- القرار النهائي وشروط الانتقال إلى PASS.

### 11. المقارنة والرجوع والاستعادة

- `git diff`, `git switch`, branch from checkpoint.
- خطوات rollback للتطبيق/قاعدة البيانات/المفتاح/الشهادة/المزامنة.
- RPO/RTO ومسار استعادة تم اختباره.

## 6. Report quality rules

- Arabic narrative may contain English technical identifiers unchanged.
- Use exact dates, versions, commits and artifact hashes.
- Separate **implemented**, **tested**, **deployed**, and **owner action required**.
- Include negative test results and limits, not only successes.
- Do not expose full secrets, tokens, personal records or exploit payloads.
- Do not claim “100% secure,” “all vulnerabilities found,” or “production ready” when material areas are untested.
- Group findings by root cause rather than inflating counts.

## 7. Minimum reconciliation checks for the two supplied report styles

Always check for contradictions around:

- whether Google Drive/OAuth/WorkManager is active, historical or removed;
- whether licensing is offline only, online lease, Apps Script or merely an interface;
- whether a signing key was actually rotated and old artifacts/history remain usable;
- whether Firebase rules/claims are changed locally versus deployed;
- whether the installer payload was rebuilt after hardening;
- whether tests ran before or after the last security code change;
- whether a legacy server/package/build remains in the delivery path;
- whether Android is Debug or properly signed Release;
- whether runtime TLS/firewall/ACL/LAN tests occurred on clean machines.
