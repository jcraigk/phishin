import React from "react";
import AppRouter from "./AppRouter";
import { NotificationProvider } from "./NotificationContext";

const App = (props) => {
  return (
    <NotificationProvider>
      <AppRouter {...props} />
    </NotificationProvider>
  );
};

export default App;
