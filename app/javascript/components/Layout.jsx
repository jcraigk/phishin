import React, { useEffect } from "react";
import { Outlet, useLocation } from "react-router-dom";
import Navbar from "./Navbar";
import Footer from "./Footer";
import { useNotification } from "./NotificationContext";

const Layout = ({ appName, user, onLogout }) => {
  const { notification, clearNotification } = useNotification();
  const location = useLocation();

  const staticLinks = [
    { path: "/faq", label: "FAQ" },
    { path: "/api-docs", label: "API" },
    { path: "/tagin-project", label: "Tagin' Project" },
    { path: "/privacy", label: "Privacy Policy" },
    { path: "/terms", label: "Terms of Service" },
    { path: "/contact-info", label: "Contact" },
  ];

  useEffect(() => {
    clearNotification();
  }, [location.pathname]);

  return (
    <>
      <Navbar appName={appName} user={user} onLogout={onLogout} staticLinks={staticLinks} />
      {notification && (
        <div className={`notification is-${notification.type}`}>
          <button className="delete" onClick={clearNotification}></button>
          {notification.message}
        </div>
      )}
      <main>
        <Outlet />
      </main>
      <Footer staticLinks={staticLinks} />
    </>
  );
};

export default Layout;
