import React, { createContext, useState, useContext } from "react";

const AppNotificationContext = createContext();

export const useNotification = () => useContext(AppNotificationContext);

export const NotificationProvider = ({ children }) => {
  const [notification, setNotification] = useState(null);

  const setAlert = (message) => {
    setNotification({ type: "danger", message });
  };

  const setNotice = (message) => {
    setNotification({ type: "success", message });
  };

  const clearNotification = () => {
    setNotification(null);
  };

  return (
    <AppNotificationContext.Provider value={{ setAlert, setNotice, clearNotification }}>
      {children}
      {notification && (
        <AppNotification
          type={notification.type}
          message={notification.message}
          clearNotification={clearNotification}
        />
      )}
    </AppNotificationContext.Provider>
  );
};

const AppNotification = ({ type, message, clearNotification }) => {
  return (
    <div className={`notification is-${type === "error" ? "danger" : "success"}`}>
      <button className="delete" onClick={clearNotification}></button>
      {message}
    </div>
  );
};

export default AppNotification;
