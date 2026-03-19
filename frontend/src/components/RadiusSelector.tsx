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

export function RadiusSelector({ location, onRadiusSelect, onBack, isLoading }: RadiusSelectorProps) {
  const displayLocation = location.includes(',') 
    ? 'your current location' 
    : `ZIP code ${location}`;

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
        <div className="loading-indicator">
          🔍 Searching for happy hours...
        </div>
      )}
    </div>
  );
}
