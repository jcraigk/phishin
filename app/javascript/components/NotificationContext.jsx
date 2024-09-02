import React, { createContext, useState, useContext } from "react";

const NotificationContext = createContext();

export const useNotification = () => useContext(NotificationContext);

export const NotificationProvider = ({ children }) => {
  const [notification, setNotification] = useState(null);

  const setAlert = (message) => {
    setNotification({ type: "danger", message, clearNotification });
  };

  const setNotice = (message) => {
    setNotification({ type: "success", message, clearNotification });
  };

  const clearNotification = () => {
    setNotification(null);
  };

  return (
    <NotificationContext.Provider value={{ notification, setAlert, setNotice, clearNotification }}>
      {children}
    </NotificationContext.Provider>
  );
};
