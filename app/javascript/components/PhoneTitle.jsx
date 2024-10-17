import React from "react";

const PhoneTitle = ({ title }) => {
  return (
    <div className="display-phone-only">
      <div className="section-title">
        <div className="title-left">{title}</div>
      </div>
    </div>
  );
};

export default PhoneTitle;
