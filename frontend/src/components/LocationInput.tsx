import { useState } from 'react';
import './LocationInput.css';

interface LocationInputProps {
  onLocationSubmit: (location: string) => void;
  isLoading?: boolean;
}

export function LocationInput({ onLocationSubmit, isLoading }: LocationInputProps) {
  const [zipCode, setZipCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isGettingLocation, setIsGettingLocation] = useState(false);

  const handleZipSubmit = () => {
    const cleaned = zipCode.trim();
    if (!cleaned) {
      setError('Please enter a ZIP code');
      return;
    }
    if (!/^\d{5}$/.test(cleaned)) {
      setError('Please enter a valid 5-digit ZIP code');
      return;
    }
    setError(null);
    onLocationSubmit(cleaned);
  };

  const handleShareLocation = () => {
    if (!navigator.geolocation) {
      setError('Geolocation is not supported by your browser');
      return;
    }

    setIsGettingLocation(true);
    setError(null);

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        onLocationSubmit(`${latitude}, ${longitude}`);
        setIsGettingLocation(false);
      },
      (err) => {
        setIsGettingLocation(false);
        if (err.code === err.PERMISSION_DENIED) {
          setError('Location access denied. Please enter a ZIP code instead.');
        } else {
          setError('Could not get your location. Please enter a ZIP code.');
        }
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleZipSubmit();
    }
  };

  return (
    <div className="location-input">
      <div className="location-header">
        <h2>🍺 Find Happy Hours Near You</h2>
        <p>Enter your ZIP code or share your location to get started</p>
      </div>

      <div className="location-options">
        <div className="zip-input-group">
          <input
            type="text"
            placeholder="Enter ZIP code"
            value={zipCode}
            onChange={(e) => setZipCode(e.target.value.replace(/\D/g, '').slice(0, 5))}
            onKeyDown={handleKeyDown}
            disabled={isLoading || isGettingLocation}
            maxLength={5}
            className="zip-input"
          />
          <button
            onClick={handleZipSubmit}
            disabled={isLoading || isGettingLocation || !zipCode.trim()}
            className="submit-btn"
          >
            {isLoading ? 'Searching...' : 'Search'}
          </button>
        </div>

        <div className="divider">
          <span>or</span>
        </div>

        <button
          onClick={handleShareLocation}
          disabled={isLoading || isGettingLocation}
          className="location-btn"
        >
          {isGettingLocation ? (
            <>📍 Getting location...</>
          ) : (
            <>📍 Use My Location</>
          )}
        </button>
      </div>

      {error && <div className="location-error">{error}</div>}
    </div>
  );
}
