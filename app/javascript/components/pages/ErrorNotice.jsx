import React from "react";
import PropTypes from "prop-types";

const ErrorNotice = ({ error }) => {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100 text-center p-6">
      <h1 className="text-4xl font-bold mb-4 text-red-600">We are so very sorry...</h1>
      <p className="text-lg text-gray-700 mb-6">
        An unexpected error has occurred. If the problem persists, please submit a{" "}
        <a
          href="https://github.com/jcraigk/phishin/issues"
          target="_blank"
          rel="noopener noreferrer"
          className="text-blue-500 underline hover:text-blue-700"
        >
          GitHub issue
        </a>.
      </p>

      {/* Display error details if available */}
      {error && (
        <div className="bg-red-100 text-red-700 p-4 rounded-lg mt-4">
          <h2 className="text-xl font-bold mb-2">Error Details</h2>
          <p>{error.message}</p>
          <pre className="bg-gray-800 text-white p-4 rounded-lg overflow-x-auto mt-2">
            {error.stack}
          </pre>
        </div>
      )}
    </div>
  );
};

ErrorNotice.propTypes = {
  error: PropTypes.shape({
    message: PropTypes.string,
    stack: PropTypes.string,
  }),
};

export default ErrorNotice;
