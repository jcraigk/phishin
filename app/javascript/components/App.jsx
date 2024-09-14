import React from "react";
import AppRouter from "./AppRouter";
import { NotificationProvider } from "./NotificationContext";
import { HelmetProvider } from "react-helmet-async"; // Import HelmetProvider

const App = (props) => {
  return (
    <HelmetProvider>
      <NotificationProvider>
        <h1>SSR Test: This should appear if SSR is working</h1>
        <AppRouter {...props} />
      </NotificationProvider>
    </HelmetProvider>
  );
};

export default App;
