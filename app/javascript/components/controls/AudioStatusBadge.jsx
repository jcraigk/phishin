import React from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faVolumeUp, faVolumeMute, faVolumeDown } from '@fortawesome/free-solid-svg-icons';
import { Tooltip } from "react-tooltip";

const AudioStatusBadge = ({ audioStatus, size = 'small' }) => {
  const getBadgeConfig = () => {
    switch (audioStatus) {
      case 'complete':
        return {
          icon: faVolumeUp,
          color: 'has-background-success',
          textColor: 'has-text-white',
          label: 'Complete Audio',
          shortLabel: 'Complete',
          tooltip: 'Complete audio available for this content'
        };
      case 'partial':
        return {
          icon: faVolumeDown,
          color: 'has-background-warning',
          textColor: 'has-text-dark',
          label: 'Partial Audio',
          shortLabel: 'Partial',
          tooltip: 'Only partial audio available for this content'
        };
      case 'missing':
        return {
          icon: faVolumeMute,
          color: 'has-background-danger',
          textColor: 'has-text-white',
          label: 'No Audio',
          shortLabel: 'Missing',
          tooltip: 'No audio available for this content'
        };
      default:
        return null;
    }
  };

  const config = getBadgeConfig();
  if (!config) return null;

  const sizeClass = size === 'large' ? 'is-medium' : 'is-small';
  const showLabel = size === 'large';
  const tooltipId = `audio-status-tooltip-${audioStatus}-${Math.random().toString(36).substr(2, 9)}`;

  return (
    <>
      <span
        className={`tag ${sizeClass} ${config.color} ${config.textColor} audio-status-badge`}
        data-tooltip-id={tooltipId}
        data-tooltip-content={config.tooltip}
      >
        <span className="icon is-small">
          <FontAwesomeIcon icon={config.icon} />
        </span>
        {showLabel && <span className="ml-1">{config.shortLabel}</span>}
      </span>
      <Tooltip id={tooltipId} className="custom-tooltip" />
    </>
  );
};

export default AudioStatusBadge;
