import { useRef, useEffect, useCallback } from 'react';
import { useChat } from './hooks/useChat';
import { ChatMessage } from './components/ChatMessage';
import { ChatInput } from './components/ChatInput';
import './App.css';

function App() {
  const { messages, isLoading, error, sendMessage, clearMessages } = useChat();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleShareLocation = useCallback(() => {
    if (!navigator.geolocation) {
      alert("Your browser doesn't support location sharing. Please type your ZIP code or city in the chat.");
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        sendMessage(`Find happy hours near my location: ${latitude.toFixed(6)}, ${longitude.toFixed(6)}`);
      },
      (err) => {
        console.error('Geolocation error:', err);
        alert("Location sharing was blocked. Please type your ZIP code or city in the chat instead.");
      },
      { enableHighAccuracy: true, timeout: 10000 }
    );
  }, [sendMessage]);

  return (
    <div className="app">
      <header className="app-header">
        <h1>🍺 Happy Hour Finder</h1>
        <p>Find the best happy hour deals near you</p>
        {messages.length > 0 && (
          <button className="clear-button" onClick={clearMessages}>
            Clear Chat
          </button>
        )}
      </header>

      <main className="chat-container">
        {messages.length === 0 ? (
          <div className="welcome-message">
            <div className="welcome-icon">🍻</div>
            <h2>Welcome!</h2>
            <p>I can help you find happy hour spots near you.</p>
            <p>Try asking something like:</p>
            <ul>
              <li>"Find happy hours near 07920"</li>
              <li>"What bars have deals in Brooklyn?"</li>
              <li>Or click 📍 to share your location</li>
            </ul>
          </div>
        ) : (
          <div className="messages-list">
            {messages.map((message) => (
              <ChatMessage key={message.id} message={message} />
            ))}
            {isLoading && (
              <div className="loading-indicator">
                <span className="dot">.</span>
                <span className="dot">.</span>
                <span className="dot">.</span>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>
        )}

        {error && (
          <div className="error-message">
            {error}
          </div>
        )}
      </main>

      <ChatInput
        onSend={sendMessage}
        onShareLocation={handleShareLocation}
        isLoading={isLoading}
      />
    </div>
  );
}

export default App;
