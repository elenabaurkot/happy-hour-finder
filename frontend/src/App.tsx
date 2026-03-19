import { useState, useCallback } from 'react';
import { LocationInput } from './components/LocationInput';
import { RadiusSelector } from './components/RadiusSelector';
import { ResultsView } from './components/ResultsView';
import type { AppStep, SearchResponse } from './types';
import './App.css';

const API_URL = 'http://localhost:3000/api';

function App() {
  const [step, setStep] = useState<AppStep>('location');
  const [location, setLocation] = useState('');
  const [radius, setRadius] = useState(5);
  const [searchResult, setSearchResult] = useState<SearchResponse | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const performSearch = useCallback(async (loc: string, rad: number, offset: number = 0) => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch(`${API_URL}/search`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          location: loc,
          radius_miles: rad,
          limit: 5,
          offset: offset,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Search failed');
      }

      if (offset > 0 && searchResult) {
        setSearchResult({
          ...data,
          results: [...searchResult.results, ...data.results],
          showing: searchResult.showing + data.showing,
        });
      } else {
        setSearchResult(data);
      }
      
      setStep('results');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Search failed');
    } finally {
      setIsLoading(false);
    }
  }, [searchResult]);

  const handleLocationSubmit = useCallback((loc: string) => {
    setLocation(loc);
    setStep('radius');
  }, []);

  const handleRadiusSelect = useCallback((rad: number) => {
    setRadius(rad);
    performSearch(location, rad);
  }, [location, performSearch]);

  const handleShowMore = useCallback(() => {
    if (searchResult) {
      performSearch(location, radius, searchResult.showing);
    }
  }, [location, radius, searchResult, performSearch]);

  const handleExpandRadius = useCallback((newRadius: number) => {
    setRadius(newRadius);
    performSearch(location, newRadius);
  }, [location, performSearch]);

  const handleNewSearch = useCallback(() => {
    setStep('location');
    setLocation('');
    setRadius(5);
    setSearchResult(null);
    setError(null);
  }, []);

  const handleBackToLocation = useCallback(() => {
    setStep('location');
  }, []);

  return (
    <div className="app">
      <header className="app-header">
        <h1>🍺 Happy Hour Finder</h1>
        <p>Find the best happy hour deals near you</p>
        {step !== 'location' && (
          <button className="clear-button" onClick={handleNewSearch}>
            Start Over
          </button>
        )}
      </header>

      <main className="main-container">
        {error && (
          <div className="error-message">
            {error}
          </div>
        )}

        {step === 'location' && (
          <LocationInput
            onLocationSubmit={handleLocationSubmit}
            isLoading={isLoading}
          />
        )}

        {step === 'radius' && (
          <RadiusSelector
            location={location}
            onRadiusSelect={handleRadiusSelect}
            onBack={handleBackToLocation}
            isLoading={isLoading}
          />
        )}

        {step === 'results' && searchResult && (
          <ResultsView
            searchResult={searchResult}
            onShowMore={handleShowMore}
            onExpandRadius={handleExpandRadius}
            onNewSearch={handleNewSearch}
            isLoading={isLoading}
            currentRadius={radius}
          />
        )}
      </main>
    </div>
  );
}

export default App;
