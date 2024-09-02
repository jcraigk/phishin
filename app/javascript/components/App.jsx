import React, { useState } from "react";
import { RouterProvider } from "react-router-dom";
import router from "./router";
import { NotificationProvider } from "./NotificationContext";

const App = (props) => {
  const [user, setUser] = useState(() => {
    const jwt = localStorage.getItem("jwt");
    const username = localStorage.getItem("username");
    const email = localStorage.getItem("email");
    return jwt ? { jwt, username, email } : null;
  });

  const handleLogin = (userData) => {
    localStorage.setItem("jwt", userData.jwt);
    localStorage.setItem("username", userData.username);
    localStorage.setItem("email", userData.email);
    setUser(userData);
  };

  const handleLogout = () => {
    localStorage.removeItem("jwt");
    localStorage.removeItem("username");
    localStorage.removeItem("email");
    setUser(null);
  };

  return (
    <NotificationProvider>
      <RouterProvider router={router({ ...props, user, handleLogin, handleLogout })} />
    </NotificationProvider>
  );
};

export default App;
