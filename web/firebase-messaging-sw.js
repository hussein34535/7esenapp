importScripts("https://www.gstatic.com/firebasejs/9.x.x/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.x.x/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "your-api-key",
  authDomain: "your-auth-domain",
  projectId: "your-project-id",
  storageBucket: "your-storage-bucket",
  messagingSenderId: "your-sender-id",
  appId: "your-app-id"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('Received background message ', payload);
}); 