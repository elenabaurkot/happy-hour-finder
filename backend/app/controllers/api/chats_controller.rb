module Api
  class ChatsController < ApplicationController
    MAX_MESSAGE_LENGTH = 1500
    MAX_WORDS = 200

    def create
      message = params[:message]&.strip

      error = validate_message(message)
      if error
        return render json: { error: error }, status: :bad_request
      end

      messages = [{ role: "user", content: message }]
      
      begin
        service = AnthropicService.new
        result = service.chat(messages)
        
        render json: {
          response: result[:response],
          tool_calls: result[:tool_calls]
        }
      rescue StandardError => e
        Rails.logger.error("Chat error: #{e.message}")
        render json: { error: "Something went wrong. Please try again." }, status: :internal_server_error
      end
    end

    private

    def validate_message(message)
      return "Message is required" if message.blank?
      return "Message too long (max #{MAX_MESSAGE_LENGTH} characters)" if message.length > MAX_MESSAGE_LENGTH
      return "Message too long (max #{MAX_WORDS} words)" if message.split.size > MAX_WORDS
      nil
    end
  end
end
