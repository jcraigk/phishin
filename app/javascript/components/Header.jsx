import React, { useState } from "react";
import PropTypes from "prop-types";
import { Link } from "react-router-dom";

const Header = ({ appName }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  // List of static pages with their paths and labels
  const staticLinks = [
    { path: "/api-docs", label: "API Docs" },
    { path: "/contact-us", label: "Contact Us" },
    { path: "/faq", label: "FAQ" },
    { path: "/privacy", label: "Privacy Policy" },
    { path: "/tagin-project", label: "Tagin Project" },
    { path: "/terms", label: "Terms of Service" },
  ];

  return (
    <header className="fixed top-0 left-0 right-0 bg-gray-800 text-white z-10 shadow-md">
      <div className="container mx-auto flex justify-between items-center p-4">
        {/* Left Section: Logo */}
        <div className="flex items-center">
          <Link to="/" className="flex items-center">
            <img
              src="/static/logo-96.png"
              alt="Site Logo"
              className="h-8 w-8 rounded-sm" // Adjusted the left margin and added border-radius
            />
          </Link>
        </div>

        {/* Center Section: App Name */}
        <div className="absolute left-1/2 transform -translate-x-1/2 text-center">
          <span className="text-xl font-semibold">{appName}</span>
        </div>

        {/* Right Section: Burger Menu */}
        <div className="relative">
          <button
            className="block text-gray-200 hover:text-white focus:text-white focus:outline-none"
            onClick={() => setIsMenuOpen(!isMenuOpen)}
          >
            <svg className="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6h16M4 12h16m-7 6h7"></path>
            </svg>
          </button>

          {/* Dropdown Menu */}
          {isMenuOpen && (
            <div className="absolute right-0 mt-2 w-48 bg-white text-gray-800 rounded-md shadow-lg py-2 z-20">
              {staticLinks.map((link) => (
                <Link
                  key={link.path}
                  to={link.path}
                  className="block px-4 py-2 text-sm hover:bg-gray-100"
                  onClick={() => setIsMenuOpen(false)}
                >
                  {link.label}
                </Link>
              ))}
            </div>
          )}
        </div>
      </div>
    </header>
  );
};

Header.propTypes = {
  appName: PropTypes.string.isRequired,
};

export default Header;
