import React from "react";
import AppRouter from "./AppRouter";
import { HelmetProvider } from "react-helmet-async";
import { NotificationProvider } from "./NotificationContext";

const App = (props) => {
  const helmetContext = {};

  return (
    <HelmetProvider context={helmetContext}>
      <NotificationProvider>
        <AppRouter {...props} />
      </NotificationProvider>
    </HelmetProvider>
  );
};

export default App;
