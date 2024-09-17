import React from "react";
import AppRouter from "./AppRouter";
import { HelmetProvider } from "react-helmet-async";
import { FeedbackProvider } from "./FeedbackContext";

const App = (props) => {
  const helmetContext = {};

  return (
    <HelmetProvider context={helmetContext}>
      <FeedbackProvider>
        <AppRouter {...props} />
      </FeedbackProvider>
    </HelmetProvider>
  );
};

export default App;
