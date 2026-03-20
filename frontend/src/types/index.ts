export interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

export interface ChatResponse {
  response: string;
  tool_calls: ToolCall[];
}

export interface ToolCall {
  name: string;
  input: Record<string, unknown>;
}

export interface ApiError {
  error: string;
}

export interface HappyHourVenue {
  name: string;
  address?: string;
  happy_hour_verified: boolean;
  happy_hour_url?: string;
  happy_hour_details?: string;
  rating?: number;
  phone?: string;
  confidence?: string;
}

export interface SearchResponse {
  results: HappyHourVenue[];
  formatted_results?: string;
  total_found: number;
  showing: number;
  offset: number;
  has_more: boolean;
  location: string;
  radius_miles: number;
  message?: string;
}

export type AppStep = 'location' | 'radius' | 'results';
