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
