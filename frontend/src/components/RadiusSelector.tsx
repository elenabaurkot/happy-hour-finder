import { useState, useEffect } from 'react';
import './RadiusSelector.css';

interface RadiusSelectorProps {
  location: string;
  onRadiusSelect: (radius: number) => void;
  onBack: () => void;
  isLoading?: boolean;
}

const RADIUS_OPTIONS = [
  { value: 1, label: '1 mile', description: 'Walking distance' },
  { value: 3, label: '3 miles', description: 'Quick drive' },
  { value: 5, label: '5 miles', description: 'Short trip' },
  { value: 10, label: '10 miles', description: 'Worth the drive' },
];

const LOADING_MESSAGES = [
  { icon: '🔍', text: 'Searching for happy hours...' },
  { icon: '🌐', text: 'Scanning venue websites...' },
  { icon: '🍺', text: 'Finding the best deals...' },
  { icon: '✨', text: 'Great things take time...' },
  { icon: '📍', text: 'Checking nearby spots...' },
  { icon: '🍸', text: 'Verifying happy hour specials...' },
  { icon: '🎯', text: 'Almost there...' },
];

export function RadiusSelector({ location, onRadiusSelect, onBack, isLoading }: RadiusSelectorProps) {
  const [loadingIndex, setLoadingIndex] = useState(0);

  useEffect(() => {
    if (!isLoading) {
      setLoadingIndex(0);
      return;
    }

    const interval = setInterval(() => {
      setLoadingIndex((prev) => (prev + 1) % LOADING_MESSAGES.length);
    }, 3000);

    return () => clearInterval(interval);
  }, [isLoading]);

  const displayLocation = location.includes(',') 
    ? 'your current location' 
    : `ZIP code ${location}`;

  const currentMessage = LOADING_MESSAGES[loadingIndex];

  return (
    <div className="radius-selector">
      <button className="back-btn" onClick={onBack} disabled={isLoading}>
        ← Change location
      </button>

      <div className="radius-header">
        <h2>How far are you willing to travel?</h2>
        <p>Searching near {displayLocation}</p>
      </div>

      <div className="radius-options">
        {RADIUS_OPTIONS.map((option) => (
          <button
            key={option.value}
            className="radius-option"
            onClick={() => onRadiusSelect(option.value)}
            disabled={isLoading}
          >
            <span className="radius-value">{option.label}</span>
            <span className="radius-desc">{option.description}</span>
          </button>
        ))}
      </div>

      {isLoading && (
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <div className="loading-message">
            <span className="loading-icon">{currentMessage.icon}</span>
            <span className="loading-text">{currentMessage.text}</span>
          </div>
          <p className="loading-subtext">This may take up to 30 seconds</p>
        </div>
      )}
    </div>
  );
}
