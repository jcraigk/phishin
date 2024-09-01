import React, { createContext, useState, useContext } from "react";
import AppNotification from "./AppNotification"; // Import the notification component

const AppNotificationContext = createContext();

export const useNotification = () => useContext(AppNotificationContext);

export const NotificationProvider = ({ children }) => {
  const [notification, setNotification] = useState(null);

  const setError = (error) => {
    setNotification({ type: "error", message: error });
  };

  const setMessage = (message) => {
    setNotification({ type: "message", message });
  };

  const clearNotification = () => {
    setNotification(null);
  };

  return (
    <AppNotificationContext.Provider value={{ notification, setError, setMessage, clearNotification }}>
      {children}
    </AppNotificationContext.Provider>
  );
};
