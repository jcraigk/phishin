import React, { useEffect } from "react";
import { Outlet, useLocation } from "react-router-dom";
import Navbar from "./Navbar";
import { useNotification } from "./NotificationContext";

const Layout = ({ appName, user, onLogout }) => {
  const { notification, clearNotification } = useNotification();
  const location = useLocation();

  useEffect(() => {
    clearNotification();
  }, [location.pathname]);

  return (
    <>
      <Navbar appName={appName} user={user} onLogout={onLogout} />
      {notification && (
        <div className={`notification is-${notification.type}`}>
          <button className="delete" onClick={notification.clearNotification}></button>
          {notification.message}
        </div>
      )}
      <main>
        <Outlet />
      </main>
    </>
  );
};

export default Layout;
