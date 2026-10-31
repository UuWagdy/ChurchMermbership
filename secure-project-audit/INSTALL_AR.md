# تثبيت مهارة Secure Project Audit

> ثبّت **المجلد كاملًا**؛ لا تنسخ `SKILL.md` وحده، لأن ملفات `references/` و`scripts/` و`agents/openai.yaml` جزء من المهارة.

## الطريقة الأسهل داخل ChatGPT

1. نزّل ملف `secure-project-audit.zip` ولا تفك ضغطه.
2. افتح الشريط الجانبي في ChatGPT، ثم **Plugins**.
3. افتح تبويب **Skills**.
4. اختر **Create** ثم **Upload from computer**.
5. اختر ملف `secure-project-audit.zip`.
6. بعد الرفع، اختر **Secure Project Audit** من قائمة المهارات عند بدء المراجعة.

ملف ZIP مجهز بمجلد علوي واحد اسمه `secure-project-audit`، وهو الشكل المناسب للرفع كحزمة.

## داخل Codex CLI أو إضافة Codex في IDE

### تثبيت للمستخدم كله — الأفضل غالبًا

فك الضغط ليصبح المسار على Windows:

```text
%USERPROFILE%\.agents\skills\secure-project-audit\SKILL.md
```

وبداخله أيضًا:

```text
secure-project-audit/
  SKILL.md
  agents/openai.yaml
  references/
  scripts/
```

المسار المكافئ على macOS/Linux:

```text
$HOME/.agents/skills/secure-project-audit/SKILL.md
```

### تثبيت داخل مشروع واحد فقط

ضع المجلد هنا داخل جذر المستودع:

```text
<PROJECT_ROOT>/.agents/skills/secure-project-audit/SKILL.md
```

يمكن أيضًا وضعه في مجلد `.agents/skills` داخل مجلد أب للمشروع؛ Codex يبحث صعودًا حتى جذر المستودع.

### تثبيت إداري على Linux

لإتاحته لكل المستخدمين على الجهاز:

```text
/etc/codex/skills/secure-project-audit/SKILL.md
```

### تشغيل المهارة

- افتح `/skills` واختر **Secure Project Audit**، أو اكتب `$secure-project-audit` داخل الطلب.
- Codex يلتقط تغييرات المهارات عادةً تلقائيًا. أعد تشغيله فقط إذا لم يظهر الاسم أو التحديث.

## التحقق قبل التثبيت

من داخل مجلد المهارة:

```powershell
python scripts\validate_skill.py
```

على macOS/Linux:

```bash
python3 scripts/validate_skill.py
```

يجب أن تظهر:

```text
PASS: secure-project-audit is structurally valid
```

## مثال استخدام قوي لمشروعك

```text
استخدم $secure-project-audit في وضع Harden على هذا المشروع المملوك لي.
أنشئ نقطة رجوع Git آمنة أولًا، ثم صنّف مصدر الحقيقة لكل جزء.
افحص Flutter/Web + Node.js/NestJS + PostgreSQL + Redis + Socket.IO،
والكاش المحلي، وإرسال التعديلات للسيرفر، والبث لباقي المستخدمين،
والصلاحيات متعددة الشركات والأجهزة، والنسخ والاستعادة والترخيص والمثبت.
أصلح فقط ما هو مصرح به، أضف اختبارات رجوع، أعد الهجوم بعد الإصلاح،
وقارن أي تقارير أمنية قديمة بالكود والـbuild الحالي.
أخرج FINAL_SECURITY_STATUS_AR.md وقرار Release Gate مبنيًا على الأدلة،
ولا تعتبر NOT TESTED نجاحًا.
```

## تحديث نسخة مثبتة سابقًا

استبدل مجلد `secure-project-audit` القديم بالمجلد الجديد كاملًا مع الحفاظ على الاسم نفسه. لا تدمج الملفات يدويًا، حتى لا تبقى مراجع قديمة أو متعارضة.
