import React from "react";
import PropTypes from "prop-types";
import logo from "../../images/logo-96.png";

const ErrorPage = () => {
  return (
    <div className="section">
      <div className="container">
        <div className="content has-text-centered">
          <a href="/">
            <img
              src={logo}
              alt="Phishin Logo"
            />
          </a>
          <h1 className="title has-text-danger mb-6">We are so very sorry...</h1>
          <p className="subtitle is-4">
            An unexpected error has occurred. If the problem persists, please submit a{" "}
            <a
              href="https://github.com/jcraigk/phishin/issues"
              target="_blank"
              rel="noopener noreferrer"
              className="has-text-link"
            >
              GitHub issue
            </a>.
          </p>
        </div>
      </div>
    </div>
  );
};

ErrorPage.propTypes = {
  error: PropTypes.shape({
    message: PropTypes.string,
    stack: PropTypes.string,
  }),
};

export default ErrorPage;
