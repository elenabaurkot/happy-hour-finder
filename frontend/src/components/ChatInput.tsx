import { useState, useCallback, type KeyboardEvent } from 'react';
import './ChatInput.css';

const MAX_CHARS = 1500;
const MAX_WORDS = 200;

interface ChatInputProps {
  onSend: (message: string) => void;
  onShareLocation: () => void;
  isLoading: boolean;
  disabled?: boolean;
}

export function ChatInput({ onSend, onShareLocation, isLoading, disabled }: ChatInputProps) {
  const [input, setInput] = useState('');
  const [validationError, setValidationError] = useState<string | null>(null);

  const charCount = input.length;

  const validate = useCallback((text: string): string | null => {
    if (text.length > MAX_CHARS) {
      return `Message too long (${text.length}/${MAX_CHARS} characters)`;
    }
    const words = text.trim().split(/\s+/).filter(Boolean).length;
    if (words > MAX_WORDS) {
      return `Message too long (${words}/${MAX_WORDS} words)`;
    }
    return null;
  }, []);

  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const value = e.target.value;
    setInput(value);
    setValidationError(validate(value));
  };

  const handleSend = () => {
    if (!input.trim() || isLoading || disabled || validationError) return;
    onSend(input.trim());
    setInput('');
    setValidationError(null);
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  return (
    <div className="chat-input-container">
      {validationError && (
        <div className="validation-error">{validationError}</div>
      )}
      <div className="chat-input-row">
        <button 
          className="location-button"
          onClick={onShareLocation}
          disabled={isLoading || disabled}
          title="Share your location"
        >
          📍
        </button>
        <div className="input-wrapper">
          <textarea
            value={input}
            onChange={handleInputChange}
            onKeyDown={handleKeyDown}
            placeholder="Ask about happy hours..."
            disabled={isLoading || disabled}
            rows={1}
          />
          <span className={`char-count ${charCount > MAX_CHARS * 0.9 ? 'warning' : ''}`}>
            {charCount}/{MAX_CHARS}
          </span>
        </div>
        <button
          className="send-button"
          onClick={handleSend}
          disabled={!input.trim() || isLoading || disabled || !!validationError}
        >
          {isLoading ? '...' : '→'}
        </button>
      </div>
    </div>
  );
}
