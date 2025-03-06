importScripts(
  "https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"
);
importScripts(
  "https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js"
);

const firebaseConfig = {
  apiKey: "AIzaSyB61_R9KigUpSsriTYFzYCPVVjDRJs8mFU",
  authDomain: "ontime-c63f1.firebaseapp.com",
  projectId: "ontime-c63f1",
  storageBucket: "ontime-c63f1.firebasestorage.app",
  messagingSenderId: "456571312261",
  appId: "1:456571312261:web:1d7c24d90acdc27d7e71ec",
  measurementId: "G-4TNCHRK7KR",
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log("Received background message ", payload);

  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
  };

  //showNotification(notificationTitle, notificationOptions);
});

function showNotification(title, body) {
  if (Notification.permission === "granted") {
    navigator.serviceWorker.ready.then((registration) => {
      registration.showNotification("Vibration Sample", {
        body: "Buzz! Buzz!",
      });
    });
  }
}
