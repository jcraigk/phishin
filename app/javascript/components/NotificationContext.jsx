import React, { createContext, useState, useContext } from "react";

const NotificationContext = createContext();

export const useNotification = () => useContext(NotificationContext);

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
    <NotificationContext.Provider value={{ notification, setError, setMessage, clearNotification }}>
      {children}
    </NotificationContext.Provider>
  );
};
