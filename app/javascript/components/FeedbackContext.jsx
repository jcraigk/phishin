import React, { createContext, useState, useContext, useEffect } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faCircleXmark } from "@fortawesome/free-solid-svg-icons";

const FeedbackContext = createContext();

export const useFeedback = () => useContext(FeedbackContext);

export const FeedbackProvider = ({ children }) => {
  const [feedback, setFeedback] = useState(null);

  const setAlert = (message) => {
    setFeedback({ type: "alert", message });
  };

  const setNotice = (message) => {
    setFeedback({ type: "notice", message });
  };

  const clearFeedback = () => {
    setFeedback(null);
  };

  useEffect(() => {
    if (feedback) {
      const timeout = setTimeout(() => {
        clearFeedback();
      }, 5000);

      return () => clearTimeout(timeout);
    }
  }, [feedback]);

  return (
    <FeedbackContext.Provider value={{ feedback, setAlert, setNotice, clearFeedback }}>
      {children}
      {feedback && (
        <div className={`feedback ${feedback.type}`}>
          <button className="close-btn" onClick={clearFeedback}>
            <FontAwesomeIcon icon={faCircleXmark} />
          </button>
          <p>{feedback.message}</p>
          <div className="progress-bar"></div>
        </div>
      )}
    </FeedbackContext.Provider>
  );
};
