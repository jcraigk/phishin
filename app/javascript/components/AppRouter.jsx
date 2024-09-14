import React, { useState, useEffect } from "react";
import { RouterProvider } from "react-router-dom";
import router from "./router";
import { useNotification } from "./NotificationContext";

const AppRouter = (props) => {
  // Initialize the user state as null for SSR (assuming user is logged out initially)
  const [user, setUser] = useState(null);

  const { setAlert, setNotice } = useNotification();

  // Handle client-side login after hydration
  useEffect(() => {
    if (typeof window !== "undefined") {
      // Only check localStorage on the client side after hydration
      const jwt = localStorage.getItem("jwt");
      const username = localStorage.getItem("username");
      const email = localStorage.getItem("email");

      if (jwt && username && email) {
        setUser({ jwt, username, email });
      }
    }
  }, []);

  // React to props passed for logging in
  useEffect(() => {
    if (props.jwt && props.username && props.email) {
      handleLogin({ jwt: props.jwt, username: props.username, email: props.email });
    }
  }, [props.jwt, props.username, props.email]);

  // React to notifications or alerts passed via props
  useEffect(() => {
    if (props.notice) {
      setNotice(props.notice);
    }
    if (props.alert) {
      setAlert(props.alert);
    }
  }, [props.notice, props.alert]);

  // Handle login and store user information in localStorage
  const handleLogin = (userData) => {
    if (typeof window !== "undefined") {
      localStorage.setItem("jwt", userData.jwt);
      localStorage.setItem("username", userData.username);
      localStorage.setItem("email", userData.email);
    }
    setUser(userData);
    setNotice("You are now logged in as " + userData.email);
  };

  // Handle logout and remove user information from localStorage
  const handleLogout = () => {
    if (typeof window !== "undefined") {
      localStorage.removeItem("jwt");
      localStorage.removeItem("username");
      localStorage.removeItem("email");
    }
    setUser(null);
    setNotice("Logged out successfully");
  };

  // Render the router on both client and server
  return (
    <RouterProvider router={router({ ...props, user, handleLogin, handleLogout })} />
  );
};

export default AppRouter;
