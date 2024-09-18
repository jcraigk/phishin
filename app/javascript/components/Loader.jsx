import React from "react";
import MoonLoader from "react-spinners/MoonLoader";

const Loader = () => {
  return (
    <div className="loader-container">
      <div className="loader-content">
        <MoonLoader color="#c7c8ca" size={120} />
      </div>
    </div>
  );
};

export default Loader;
