require('dotenv').config();
const express = require('express');
const axios = require('axios');
const crypto = require('crypto');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors()); // السماح للتطبيق (Flutter) بالاتصال بالسيرفر

// ==========================================
// 1. المتغيرات والبيانات السرية الخاصة بـ Paymob
// ==========================================
// ملاحظة: يُفضل دائماً وضع هذه المتغيرات في ملف .env في سيرفرك الحقيقي
const PAYMOB_API_KEY = process.env.PAYMOB_API_KEY || "ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TkRJMU5EVTJMQ0p1WVcxbElqb2lNVGN4TURNMU5ERXhPUzQwTnpFeE56TWlmUS50S0dFMG5RMnFjX3lMWEEyTUg3Y0VCQUhnZVVhRUhPT2Q5QTRKUUJrSDNCbU45cFk5Vjh2bFlabUlVcWV3QVNXTnI0ZzRFQklmcXIyRVBmc2NreU1EUQ==";
const PAYMOB_HMAC_SECRET = process.env.PAYMOB_HMAC_SECRET || "B2CE1EC9FAD8D4347F829B2BFF5A6A6A";
const PAYMOB_CARD_INTEGRATION_ID = process.env.PAYMOB_CARD_INTEGRATION_ID || "4540485";
const PAYMOB_CARD_IFRAME_ID = process.env.PAYMOB_CARD_IFRAME_ID || "669175";


// ==========================================
// 2. إنشاء جلسة الدفع (يتم استدعاؤها من تطبيق Flutter)
// ==========================================
app.post('/api/paymob/create-session', async (req, res) => {
    try {
        const { uid, packageId, couponCode } = req.body;
        
        // --- 1. تحديد السعر وبيانات العميل ---
        // (في تطبيقك الحقيقي، يجب جلب السعر بناءً على الـ packageId من قاعدة البيانات)
        const price = 100; // السعر بالجنيه المصري (مثال)
        const userEmail = "user@hesen.com"; // البريد الإلكتروني للعميل
        const userPhone = "+201000000000"; // هاتف العميل
        const userName = "عميل تطبيق هسن"; 

        // --- 2. الخطوة الأولى: تسجيل الدخول وجلب التوكن (Authentication) ---
        const authResponse = await axios.post('https://accept.paymob.com/api/auth/tokens', {
            api_key: PAYMOB_API_KEY
        });
        const authToken = authResponse.data.token;

        // --- 3. الخطوة الثانية: تسجيل الطلب (Order Registration) ---
        const orderResponse = await axios.post('https://accept.paymob.com/api/ecommerce/orders', {
            auth_token: authToken,
            delivery_needed: "false",
            amount_cents: Math.round(price * 100), // السعر بالقرش (100 جنيه = 10000 قرش)
            currency: "EGP",
            items: [] // يمكن إضافة تفاصيل الباقة هنا إن شئت
        });
        const orderId = orderResponse.data.id;

        // --- 4. الخطوة الثالثة: توليد مفتاح الدفع (Payment Key Generation) ---
        const paymentKeyResponse = await axios.post('https://accept.paymob.com/api/acceptance/payment_keys', {
            auth_token: authToken,
            amount_cents: Math.round(price * 100),
            expiration: 3600, // صلاحية الرابط (بالثواني)
            order_id: orderId,
            billing_data: {
                apartment: "NA",
                email: userEmail,
                floor: "NA",
                first_name: userName.split(' ')[0] || "Guest",
                street: "NA",
                building: "NA",
                phone_number: userPhone,
                shipping_method: "PKG",
                postal_code: "NA",
                city: "Cairo",
                country: "EG",
                last_name: userName.split(' ')[1] || "User",
                state: "Cairo"
            },
            currency: "EGP",
            integration_id: PAYMOB_CARD_INTEGRATION_ID,
            lock_order_when_paid: "true"
        });
        const paymentKey = paymentKeyResponse.data.token;

        // --- 5. تكوين رابط الدفع النهائي وإرساله لتطبيق Flutter ---
        const checkoutUrl = `https://accept.paymob.com/api/acceptance/iframes/${PAYMOB_CARD_IFRAME_ID}?payment_token=${paymentKey}`;
        
        console.log(`تم إنشاء جلسة دفع جديدة بنجاح، رقم الطلب: ${orderId}`);
        return res.status(200).json({ checkout_url: checkoutUrl, order_id: orderId });

    } catch (error) {
        console.error("حدث خطأ أثناء الاتصال بـ Paymob:", error.response ? error.response.data : error.message);
        return res.status(500).json({ error: "فشل بدء الجلسة مع بوابة الدفع الإلكتروني" });
    }
});


// ==========================================
// 3. استقبال إشعارات الدفع من Paymob (Webhook Callback)
// ==========================================
app.post('/api/paymob/callback', async (req, res) => {
    try {
        const { hmac, obj } = req.body; // hmac موجود في الرابط، ولكن Express يمكن أن يستقبله في بعض التكوينات من req.query.hmac

        // التأكد من استلام الـ HMAC من مسار الـ Query
        const receivedHmac = req.query.hmac || hmac;
        
        if (!receivedHmac || !obj) {
             return res.status(400).send("Bad Request");
        }

        // --- 1. تجميع البيانات لتشفيرها ومقارنتها (لضمان الأمان) ---
        const hmacString = 
            obj.amount_cents +
            obj.created_at +
            obj.currency +
            obj.error_occured +
            obj.has_parent_transaction +
            obj.id +
            obj.integration_id +
            obj.is_3d_secure +
            obj.is_auth +
            obj.is_capture +
            obj.is_refunded +
            obj.is_standalone_payment +
            obj.source_data.pan +
            obj.source_data.sub_type +
            obj.source_data.type +
            obj.success;

        const calculatedHmac = crypto.createHmac('sha512', PAYMOB_HMAC_SECRET)
            .update(hmacString)
            .digest('hex');

        // --- 2. التحقق من تطابق التشفير ---
        if (receivedHmac !== calculatedHmac) {
            console.error("تحذير: التوقيع غير متطابق! محاولة اختراق أو بيانات خاطئة.");
            return res.status(401).send("Unauthorized Signature");
        }

        // --- 3. في حالة نجاح الدفع، قم بتفعيل الاشتراك ---
        if (obj.success === true) {
            const orderId = obj.order.id;
            const amountPaid = obj.amount_cents / 100;
            
            console.log(`[نجاح] تمت عملية الدفع للطلب رقم ${orderId} بقيمة ${amountPaid} جنيه.`);
            
            // 💡 هنا يجب كتابة كود تعديل قاعدة البيانات (تفعيل اشتراك المستخدم)
            // مثال:
            // await activateUserSubscription(orderId);
        } else {
            console.log(`[فشل] لم تنجح عملية الدفع للطلب رقم ${obj.order.id}`);
        }

        // يجب دائماً الرد بـ 200 OK حتى يتوقف Paymob عن إرسال الإشعار مرة أخرى
        return res.status(200).send("OK");

    } catch (error) {
        console.error("حدث خطأ في استقبال الـ Webhook:", error);
        return res.status(500).send("Internal Server Error");
    }
});


// ==========================================
// 4. تشغيل السيرفر
// ==========================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`سيرفر الدفع (Paymob) يعمل الآن على المنفذ ${PORT}`);
    console.log(`تأكد من إرسال هذا الرابط إلى لوحة تحكم Paymob كـ Webhook:`);
    console.log(`http://[ip-سيرفر-الابونتو]:${PORT}/api/paymob/callback`);
});
