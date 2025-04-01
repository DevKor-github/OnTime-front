const init = () => {
  const requestNotificationPermission = () => {
    return Notification.requestPermission();
  };

  window._requestNotificationPermission = requestNotificationPermission;
};

window.onload = () => {
  init();
};
