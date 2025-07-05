import React from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faVolumeUp, faVolumeMute, faVolumeDown } from '@fortawesome/free-solid-svg-icons';

const AudioStatusBadge = ({ audioStatus, size = 'small' }) => {
  const getBadgeConfig = () => {
    switch (audioStatus) {
      case 'complete':
        return {
          icon: faVolumeUp,
          color: 'has-background-success',
          textColor: 'has-text-white',
          label: 'Complete Audio',
          shortLabel: 'Complete'
        };
      case 'partial':
        return {
          icon: faVolumeDown,
          color: 'has-background-warning',
          textColor: 'has-text-dark',
          label: 'Partial Audio',
          shortLabel: 'Partial'
        };
      case 'missing':
        return {
          icon: faVolumeMute,
          color: 'has-background-danger',
          textColor: 'has-text-white',
          label: 'No Audio',
          shortLabel: 'Missing'
        };
      default:
        return null;
    }
  };

  const config = getBadgeConfig();
  if (!config) return null;

  const sizeClass = size === 'large' ? 'is-medium' : 'is-small';
  const showLabel = size === 'large';

  return (
    <span className={`tag ${sizeClass} ${config.color} ${config.textColor} audio-status-badge`}>
      <span className="icon is-small">
        <FontAwesomeIcon icon={config.icon} />
      </span>
      {showLabel && <span className="ml-1">{config.shortLabel}</span>}
    </span>
  );
};

export default AudioStatusBadge;
