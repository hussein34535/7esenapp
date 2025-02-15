import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          textAlign: TextAlign.right,
          text: TextSpan(
            style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge!.color),
            children: [
              TextSpan(
                text: ' 7eSen TV تطبيق\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: 'تاريخ آخر تحديث: 2023-11-19\n\n',
              ),
              TextSpan(
                text: 'مقدمة\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    ' 7eSen TV ("التطبيق") يحترم خصوصيتك ويلتزم بحماية معلوماتك الشخصية. توضح سياسة الخصوصية هذه كيفية جمع واستخدام وحماية معلوماتك عندما تستخدم تطبيقنا.\n\n',
              ),
              TextSpan(
                text: 'المعلومات التي نجمعها\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: ' 7eSen TV تطبيق',
              ),
              TextSpan(
                text:
                    '**لا يجمع أي معلومات تعريف شخصية (PII) مثل الاسم أو عنوان البريد الإلكتروني أو رقم الهاتف بشكل مباشر.**\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'قد نجمع معلومات غير شخصية بشكل تلقائي عند استخدامك للتطبيق، مثل:\n\n',
              ),
              TextSpan(
                text:
                    '*   **بيانات الاستخدام:** معلومات حول كيفية استخدامك للتطبيق، مثل الصفحات التي زرتها، والميزات التي استخدمتها، ومدة استخدامك للتطبيق.\n',
              ),
              TextSpan(
                text:
                    '*   **معلومات الجهاز:** نوع الجهاز، نظام التشغيل، معرف الجهاز الفريد (UDID)، عنوان IP.\n\n',
              ),
              TextSpan(
                text: 'خدمات الطرف الثالث:\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    '*   **Firebase:** نستخدم خدمات Firebase من جوجل لتوفير الإشعارات الهامة لمستخدمي التطبيق. Firebase قد يجمع بيانات معينة حول استخدامك للتطبيق لأغراض التحليل وتقديم الخدمات. يمكنك مراجعة سياسة خصوصية Firebase لمعرفة المزيد من التفاصيل: ',
              ),
              TextSpan(
                text: 'https://policies.google.com/privacy',
                style: TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(Uri.parse('https://policies.google.com/privacy'));
                  },
              ),
              TextSpan(text: '\n\n'),
              TextSpan(
                text: 'كيف نستخدم المعلومات\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'نحن نستخدم المعلومات غير الشخصية التي نجمعها للأغراض التالية:\n\n',
              ),
              TextSpan(
                text:
                    '*   **تحسين التطبيق:** لفهم كيفية استخدام المستخدمين للتطبيق وتحسينه وتطوير ميزات جديدة.\n',
              ),
              TextSpan(
                text:
                    '*   **تحليل الاتجاهات:** لتحليل الاتجاهات وأنماط الاستخدام العام للتطبيق.\n',
              ),
              TextSpan(
                text:
                    '*   **تشغيل الإشعارات:** استخدام Firebase لإرسال إشعارات هامة ومفيدة لمستخدمي التطبيق.\n\n',
              ),
              TextSpan(
                text: 'مشاركة المعلومات\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: 'نحن ',
              ),
              TextSpan(
                text:
                    '**لا نشارك أي معلومات تعريف شخصية** مع أطراف ثالثة، لأن تطبيقنا لا يجمع هذا النوع من المعلومات بشكل مباشر.\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'قد تتم مشاركة معلومات غير شخصية مع خدمات الطرف الثالث التي نستخدمها فقط في نطاق الخدمات التي يقدمونها لنا (مثل Firebase).\n\n',
              ),
              TextSpan(
                text: 'أمن المعلومات\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'نحن نتخذ تدابير أمنية معقولة لحماية المعلومات التي نجمعها. ومع ذلك، يرجى ملاحظة أنه لا يوجد نظام أمني مثالي، ولا يمكننا ضمان الأمان المطلق لمعلوماتك.\n\n',
              ),
              TextSpan(
                text: 'تغييرات على سياسة الخصوصية\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر. سنقوم بإعلامك بأي تغييرات جوهرية عن طريق نشر سياسة الخصوصية الجديدة في هذه الصفحة أو من خلال إشعار داخل التطبيق. يُنصح بمراجعة سياسة الخصوصية هذه بشكل دوري للاطلاع على أي تحديثات.\n\n',
              ),
              TextSpan(
                text: 'خصوصية الأطفال\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    'تطبيقنا غير مخصص للأطفال دون سن 13 عامًا. نحن لا نجمع معلومات شخصية عن عمد من الأطفال دون سن 13 عامًا. إذا كنت ولي أمر أو وصي وتعتقد أن طفلك قد زودنا بمعلومات شخصية، فيرجى الاتصال بنا وسنتخذ خطوات لحذف هذه المعلومات.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
