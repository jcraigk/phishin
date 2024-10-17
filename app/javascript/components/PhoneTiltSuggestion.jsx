import React from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faRotateLeft } from "@fortawesome/free-solid-svg-icons";

const PhoneTiltSuggestion = () => {
  return (
    <div className="display-phone-only">
      <div className="box has-text-centered p-1 mt-2">
        <p>
          <FontAwesomeIcon icon={faRotateLeft} />
          {" "}
          Switch to landscape for more options
        </p>
      </div>
    </div>
  );
};

export default PhoneTiltSuggestion;
