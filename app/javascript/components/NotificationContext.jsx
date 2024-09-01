import React, { createContext, useState, useContext } from "react";

const AppNotificationContext = createContext();

export const useNotification = () => useContext(AppNotificationContext);

export const NotificationProvider = ({ children }) => {
  const [notification, setNotification] = useState(null);

  const setError = (message) => {
    setNotification({ type: "danger", message, clearNotification });
  };

  const setMessage = (message) => {
    setNotification({ type: "success", message, clearNotification });
  };

  const clearNotification = () => {
    setNotification(null);
  };

  return (
    <AppNotificationContext.Provider value={{ notification, setError, setMessage }}>
      {children}
    </AppNotificationContext.Provider>
  );
};
