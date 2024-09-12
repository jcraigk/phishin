import React from "react";
import { Link } from "react-router-dom";

const Footer = ({ staticLinks, activeTrack }) => (
  <footer className={activeTrack ? 'with-player' : ''}>
    {staticLinks.map((link) => (
      <Link key={link.path} to={link.path}>
        {link.label}
      </Link>
    ))}
  </footer>
);

export default Footer;
