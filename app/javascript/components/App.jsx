import React from "react";
import { HelmetProvider } from "react-helmet-async";
import AppRouter from "./AppRouter";
import { FeedbackProvider } from "./FeedbackContext";

const App = (props) => {
  const helmetContext = {};

  return (
    <HelmetProvider context={helmetContext}>
      <FeedbackProvider>
        <div className="root-layout">
          <AppRouter {...props} />
        </div>
      </FeedbackProvider>
    </HelmetProvider>
  );
};

export default App;
