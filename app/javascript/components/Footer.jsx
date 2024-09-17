import React from "react";
import { Link } from "react-router-dom";

const Footer = () => {
  const links = [
    { path: "/faq", label: "FAQ" },
    { path: "/privacy", label: "Privacy Policy" },
    { path: "/terms", label: "Terms of Service" },
    { path: "/contact-info", label: "Contact" },
  ];

  return (
    <footer>
      {links.map((link) => (
        <Link key={link.path} to={link.path}>
          {link.label}
        </Link>
      ))}
    </footer>
  );
};

export default Footer;
