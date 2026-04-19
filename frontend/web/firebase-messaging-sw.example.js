importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Plantilla de Firebase Messaging Service Worker
// Copia este archivo a firebase-messaging-sw.js y rellena con tus claves de Firebase Web App
firebase.initializeApp({
  apiKey: 'TU_API_KEY_AQUI',
  appId: 'TU_APP_ID_AQUI',
  messagingSenderId: 'TU_SENDER_ID_AQUI',
  projectId: 'TU_PROJECT_ID_AQUI',
  authDomain: 'TU_PROJECT_ID.firebaseapp.com',
  storageBucket: 'TU_PROJECT_ID.firebasestorage.app',
  measurementId: 'TU_MEASUREMENT_ID_AQUI',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification ?? {};
  const title = notification.title || 'RESERVIVES';
  const options = {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow('/'));
});
