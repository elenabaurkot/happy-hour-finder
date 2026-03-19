module Api
  class ChatsController < ApplicationController
    MAX_MESSAGE_LENGTH = 1500
    MAX_WORDS = 200
    MAX_HISTORY_MESSAGES = 10

    def create
      message = params[:message]&.strip
      conversation_history = params[:conversation_history] || []

      error = validate_message(message)
      if error
        return render json: { error: error }, status: :bad_request
      end

      # Build messages array with history for context
      messages = build_messages_with_history(conversation_history, message)
      
      begin
        service = AnthropicService.new
        result = service.chat(messages)
        
        render json: {
          response: result[:response],
          tool_calls: result[:tool_calls],
          token_usage: result[:token_usage]
        }
      rescue StandardError => e
        Rails.logger.error("Chat error: #{e.message}")
        render json: { error: "Something went wrong. Please try again." }, status: :internal_server_error
      end
    end

    private

    def build_messages_with_history(history, current_message)
      messages = []
      
      # Add recent conversation history (limited to save tokens)
      recent_history = history.last(MAX_HISTORY_MESSAGES)
      recent_history.each do |msg|
        role = msg["role"] || msg[:role]
        content = msg["content"] || msg[:content]
        next if role.blank? || content.blank?
        
        # Only include user and assistant messages (not system)
        if role.to_s.in?(["user", "assistant"])
          messages << { role: role.to_s, content: content.to_s }
        end
      end
      
      # Add current user message
      messages << { role: "user", content: current_message }
      
      messages
    end

    def validate_message(message)
      return "Message is required" if message.blank?
      return "Message too long (max #{MAX_MESSAGE_LENGTH} characters)" if message.length > MAX_MESSAGE_LENGTH
      return "Message too long (max #{MAX_WORDS} words)" if message.split.size > MAX_WORDS
      nil
    end
  end
end
