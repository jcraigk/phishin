import React, { useState } from "react";
import PropTypes from "prop-types";
import { Link } from "react-router-dom";

const Header = ({ appName }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  // List of static pages with their paths and labels
  const staticLinks = [
    { path: "/faq", label: "FAQ" },
    { path: "/api-docs", label: "API" },
    { path: "/tagin-project", label: "Tagin' Project" },
    { path: "/privacy", label: "Privacy Policy" },
    { path: "/terms", label: "Terms of Service" },
    { path: "/contact-info", label: "Contact" },
  ];

  return (
    <header className="fixed top-0 left-0 right-0 bg-gray-800 text-white z-10 shadow-md">
      <div className="flex justify-between items-center p-4">
        {/* Left Section: Logo */}
        <div className="ml-4">
          <Link to="/" className="flex items-center">
            <img
              src="/static/logo-96.png"
              alt="Site Logo"
              className="h-8 w-8 rounded-sm"
            />
          </Link>
        </div>

        {/* Center Section: App Name */}
        <div className="absolute left-1/2 transform -translate-x-1/2 text-center">
          <span className="text-xl font-semibold">{appName}</span>
        </div>

        {/* Right Section: Burger Menu */}
        <div className="mr-4 relative">
          <button
            className="block text-gray-200 hover:text-white focus:text-white focus:outline-none"
            onClick={() => setIsMenuOpen(!isMenuOpen)}
          >
            <svg
              className="h-6 w-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M4 6h16M4 12h16m-7 6h7"
              ></path>
            </svg>
          </button>
        </div>

        {/* Full-screen Mobile Menu */}
        {isMenuOpen && (
          <div className="fixed inset-0 bg-gray-900 bg-opacity-90 z-20 flex flex-col items-center justify-center">
            <button
              className="absolute top-4 right-4 text-white focus:outline-none"
              onClick={() => setIsMenuOpen(false)}
            >
              <svg
                className="h-8 w-8"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="2"
                  d="M6 18L18 6M6 6l12 12"
                ></path>
              </svg>
            </button>
            <nav className="space-y-4 w-full px-8">
              {staticLinks.map((link) => (
                <Link
                  key={link.path}
                  to={link.path}
                  className="block w-full bg-blue-500 text-white py-4 text-center rounded-lg text-8xl font-semibold hover:bg-blue-600"
                  onClick={() => setIsMenuOpen(false)}
                >
                  {link.label}
                </Link>
              ))}
            </nav>
          </div>
        )}
      </div>
    </header>
  );
};

Header.propTypes = {
  appName: PropTypes.string.isRequired,
};

export default Header;
