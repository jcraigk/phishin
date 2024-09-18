import React, { useState } from "react";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";
import { toggleLike } from "./utils";
import { useFeedback } from "./FeedbackContext";

const ShowLikeButton = ({ show }) => {
  const { setAlert, setNotice } = useFeedback();
  const [likedByUser, setLikedByUser] = useState(show.liked_by_user);
  const [likesCount, setLikesCount] = useState(show.likes_count);

  const handleLikeToggle = async (e) => {
    e.preventDefault();
    let jwt = null;

    if (typeof window !== "undefined") {
      jwt = localStorage.getItem("jwt");
      if (!jwt) {
        setAlert("Please login to like a show");
        return;
      }
    }

    const result = await toggleLike({
      id: show.id,
      type: "Show",
      isLiked: likedByUser,
      jwt,
    });

    if (result.success) {
      setLikedByUser(result.isLiked);
      setLikesCount(result.isLiked ? likesCount + 1 : likesCount - 1);
      setNotice("Like saved");
    } else {
      console.log(result);
      setAlert("Like failed to save");
    }
  };

  return (
    <div className="like-button">
      <FontAwesomeIcon
        icon={faHeart}
        className={`heart-icon ${likedByUser ? "liked" : ""}`}
        onClick={handleLikeToggle}
      />{" "}
      {likesCount}
    </div>
  );
};

export default ShowLikeButton;
