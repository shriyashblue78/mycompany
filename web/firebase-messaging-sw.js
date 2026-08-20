importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// Initialize Firebase App in the Service Worker
firebase.initializeApp({
  apiKey: "AIzaSyAC40uAPOJuvHyQZhmO-g5k0bXSElM9m7M",
  authDomain: "erpcomp-6ae45.firebaseapp.com",
  projectId: "erpcomp-6ae45",
  storageBucket: "erpcomp-6ae45.firebasestorage.app",
  messagingSenderId: "233953167777",
  appId: "1:233953167777:web:53498ab57dbf24500e63e0"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  const notificationTitle = payload.notification?.title || "New Notification";
  const notificationOptions = {
    body: payload.notification?.body || "",
    icon: "/favicon.png"
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
