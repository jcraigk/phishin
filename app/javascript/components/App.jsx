import React from "react";
import { HelmetProvider } from "react-helmet-async";
import AppRouter from "./util/AppRouter";
import { FeedbackProvider } from "./controls/FeedbackContext";

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
