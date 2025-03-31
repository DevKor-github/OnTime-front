const init = () => {
  const requestNotificationPermission = () => {
    return Notification.requestPermission();
  };

  const isInStandaloneMode = () => {
    return (
      (window.matchMedia("(display-mode: standalone)").matches ?? false) ||
      (window.navigator.standalone ?? false)
    );
  };

  window._isInStandaloneMode = isInStandaloneMode;
  window._requestNotificationPermission = requestNotificationPermission;
};

window.onload = () => {
  init();
};
