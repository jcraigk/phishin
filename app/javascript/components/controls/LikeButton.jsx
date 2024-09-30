import React, { useState } from "react";
import { useOutletContext } from "react-router-dom";
import { toggleLike } from "../helpers/utils";
import { useFeedback } from "./FeedbackContext";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faHeart } from "@fortawesome/free-solid-svg-icons";

const LikeButton = ({ likable, type }) => {
  const { setAlert, setNotice } = useFeedback();
  const [likedByUser, setLikedByUser] = useState(likable.liked_by_user);
  const [likesCount, setLikesCount] = useState(likable.likes_count);
  const { user } = useOutletContext();

  const handleLikeToggle = async (e) => {
    e.stopPropagation();
    if (user === "anonymous") {
      setAlert("You must login to submit likes");
      return;
    }

    const result = await toggleLike({
      id: likable.id,
      type,
      isLiked: likedByUser
    });

    if (result.success) {
      setLikedByUser(result.isLiked);
      setLikesCount(result.isLiked ? likesCount + 1 : likesCount - 1);
      setNotice("Like saved");
    } else {
      setAlert("Like failed to save");
    }
  };

  return (
    <div className="like-container">
      <FontAwesomeIcon
        icon={faHeart}
        className={`heart-icon ${likedByUser ? "liked" : ""}`}
        onClick={handleLikeToggle}
      />{" "}
      <span className="likes-count">
        {likesCount}
      </span>
    </div>
  );
};

export default LikeButton;
