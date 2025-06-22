export const formatNumber = (number, label = "") => {
  const formattedNumber = number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `${formattedNumber} ${label}${number !== 1 && label ? "s" : ""}`;
};

export const formatDurationShow = (milliseconds) => {
  const totalMinutes = Math.floor(milliseconds / 60000);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;

  if (hours > 0) {
    return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`;
  } else {
    return `${minutes}m`;
  }
};

export const formatDurationTrack = (milliseconds) => {
  const totalSeconds = Math.floor(milliseconds / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const formattedMinutes = hours > 0 ? minutes.toString().padStart(2, "0") : minutes.toString();
  const formattedSeconds = seconds.toString().padStart(2, "0");

  if (hours > 0) {
    return `${hours}:${formattedMinutes}:${formattedSeconds}`;
  } else {
    return `${formattedMinutes}:${formattedSeconds}`;
  }
};

export const formatDate = (dateString) => {
  if (!dateString) return "";

  // Extract the first 10 characters to get the YYYY-MM-DD format
  const datePart = dateString.slice(0, 10);
  const [year, month, day] = datePart.split("-").map(Number);
  const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  const formattedDate = `${monthNames[month - 1]} ${day}, ${year}`;
  return formattedDate;
};

export const toggleLike = async ({ id, type, isLiked }) => {
  const url = `/api/v2/likes?likable_type=${type}&likable_id=${id}`;
  const method = isLiked ? "DELETE" : "POST";
  let token = null;

  if (typeof window !== "undefined" && window.localStorage) {
    token = localStorage.getItem("jwt");
  }

  try {
    const response = await fetch(url, {
      method,
      headers: { "X-Auth-Token": token },
    });

    if (response.ok) {
      return { success: true, isLiked: !isLiked };
    } else {
      console.error("Failed to toggle like");
      return { success: false };
    }
  } catch (error) {
    console.error("Error toggling like:", error);
    return { success: false };
  }
};

export const authFetch = async (url, options = {}) => {
  let token = null;

  if (typeof window !== "undefined" && window.localStorage) {
    token = localStorage.getItem("jwt");
  }

  const headers = {
    "Content-Type": "application/json",
    ...options.headers,
    ...(token ? { "X-Auth-Token": token } : {}),
  };

  const response = await fetch(url, {
    ...options,
    headers,
  });

  return response;
};

export const parseTimeParam = (t) => {
  if (!t) return null;

  // Handle "1m30s" format (e.g., "1m30s" = 90 seconds)
  if (t.includes('m') || t.includes('s')) {
    let totalSeconds = 0;

    // Extract minutes if present
    const minuteMatch = t.match(/(\d+(?:\.\d+)?)m/);
    if (minuteMatch) {
      totalSeconds += parseFloat(minuteMatch[1]) * 60;
    }

    // Extract seconds if present
    const secondMatch = t.match(/(\d+(?:\.\d+)?)s/);
    if (secondMatch) {
      totalSeconds += parseFloat(secondMatch[1]);
    }

    return totalSeconds || null;
  }

  // Handle "1:30" format
  if (t.includes(":")) {
    const parts = t.split(":");
    if (parts.length !== 2) return null;

    const [minutes, seconds] = parts.map(Number);

    // Validate the format
    if (isNaN(minutes) || isNaN(seconds) || seconds >= 60 || seconds < 0 || minutes < 0) {
      return null;
    }

    return minutes * 60 + seconds;
  }

  // Handle plain number (seconds)
  const num = Number(t);
  return isNaN(num) ? null : num;
};

export const truncate = (str, n) => {
  if (!str) return "";
  return str.length > n ? str.slice(0, n) + "..." : str;
};
