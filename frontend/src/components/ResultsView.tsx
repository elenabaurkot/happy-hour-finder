import type { SearchResponse } from '../types';
import './ResultsView.css';

interface ResultsViewProps {
  searchResult: SearchResponse;
  onShowMore: () => void;
  onExpandRadius: (newRadius: number) => void;
  onNewSearch: () => void;
  isLoading?: boolean;
  currentRadius: number;
}

const EXPAND_OPTIONS = [
  { from: 1, to: 3 },
  { from: 3, to: 5 },
  { from: 5, to: 10 },
  { from: 10, to: 15 },
];

export function ResultsView({
  searchResult,
  onShowMore,
  onExpandRadius,
  onNewSearch,
  isLoading,
  currentRadius,
}: ResultsViewProps) {
  const { results, total_found, showing, has_more, location, radius_miles, message } = searchResult;

  const displayLocation = location.includes(',') 
    ? 'your location' 
    : `ZIP ${location}`;

  const expandOption = EXPAND_OPTIONS.find(opt => opt.from === currentRadius);

  if (results.length === 0) {
    return (
      <div className="results-view">
        <div className="results-header">
          <h2>No Happy Hours Found</h2>
          <p>Within {radius_miles} miles of {displayLocation}</p>
        </div>

        <div className="no-results-message">
          <p>{message || "We couldn't find any verified happy hours in this area."}</p>
        </div>

        <div className="results-actions">
          {expandOption && (
            <button
              className="action-btn primary"
              onClick={() => onExpandRadius(expandOption.to)}
              disabled={isLoading}
            >
              Expand to {expandOption.to} miles
            </button>
          )}
          <button
            className="action-btn secondary"
            onClick={onNewSearch}
            disabled={isLoading}
          >
            Search Different Area
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="results-view">
      <div className="results-header">
        <h2>🍺 Found {total_found} Happy Hour{total_found !== 1 ? 's' : ''}</h2>
        <p>Within {radius_miles} miles of {displayLocation}</p>
      </div>

      <div className="results-content">
        <div className="venue-list">
          {results.map((venue, index) => (
            <div key={`${venue.name}-${index}`} className="venue-card">
              <h3>🍸 {venue.name}</h3>
              {venue.address ? (
                <p className="venue-address">📍 {venue.address}</p>
              ) : (
                <p className="venue-address venue-address-missing">📍 Address not listed</p>
              )}
              {venue.happy_hour_details && (
                <p className="venue-details">{venue.happy_hour_details.slice(0, 200)}{venue.happy_hour_details.length > 200 ? '...' : ''}</p>
              )}
              <div className="venue-footer">
                {venue.happy_hour_url && (
                  <a 
                    href={venue.happy_hour_url} 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="venue-link"
                  >
                    🔗 View Menu
                  </a>
                )}
                {venue.rating && (
                  <span className="venue-rating">⭐ {venue.rating}/5</span>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      {isLoading && (
        <div className="expanding-loader">
          <div className="expanding-spinner"></div>
          <span>Finding more happy hours...</span>
        </div>
      )}

      <div className="results-actions">
        {has_more && !isLoading && (
          <button
            className="action-btn primary"
            onClick={onShowMore}
            disabled={isLoading}
          >
            Show {Math.min(3, total_found - showing)} More
          </button>
        )}
        
        {!has_more && expandOption && !isLoading && (
          <button
            className="action-btn primary"
            onClick={() => onExpandRadius(expandOption.to)}
            disabled={isLoading}
          >
            Expand to {expandOption.to} miles
          </button>
        )}

        {!isLoading && (
          <button
            className="action-btn secondary"
            onClick={onNewSearch}
            disabled={isLoading}
          >
            Search Different Area
          </button>
        )}
      </div>

      <div className="results-footer">
        <p>Showing {showing} of {total_found} verified happy hours</p>
      </div>
    </div>
  );
}
