importScripts(
  "https://www.gstatic.com/firebasejs/11.4.0/firebase-app-compat.js"
);
importScripts(
  "https://www.gstatic.com/firebasejs/11.4.0/firebase-messaging-compat.js"
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

function showNotification(title, body) {
  if (Notification.permission === "granted") {
    self.registration.showNotification(title, {
      body: body,
    });
  }
}
self.addEventListener("push", (event) => {
  const data = event.data.json();
  console.log("New notification", data.data);
  event.waitUntil(showNotification(data.data.title, data.data.content));
});
