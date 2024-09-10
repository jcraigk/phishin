import React, { createContext, useState, useContext, useEffect } from "react";

const NotificationContext = createContext();

export const useNotification = () => useContext(NotificationContext);

export const NotificationProvider = ({ children }) => {
  const [notification, setNotification] = useState(null);

  const setAlert = (message) => {
    setNotification({ type: "is-danger", message, clearNotification });
  };

  const setNotice = (message) => {
    setNotification({ type: "is-success", message, clearNotification });
  };

  const clearNotification = () => {
    setNotification(null);
  };

  useEffect(() => {
    if (notification) {
      const timeout = setTimeout(() => {
        clearNotification();
      }, 5000);

      return () => clearTimeout(timeout);
    }
  }, [notification]);

  return (
    <NotificationContext.Provider value={{ notification, setAlert, setNotice, clearNotification }}>
      {children}
      {notification && (
        <div className={`notification ${notification.type}`}>
          <button className="close-btn" onClick={clearNotification}>&times;</button>
          <p>{notification.message}</p>
          <div className="progress-bar"></div>
        </div>
      )}
    </NotificationContext.Provider>
  );
};
