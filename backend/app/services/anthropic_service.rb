class AnthropicService
  MAX_OUTPUT_TOKENS = 800
  MAX_TOOL_RESULT_LENGTH = 1500
  MAX_CONVERSATION_TURNS = 6

  TOOLS = [
    {
      name: "search_happy_hours",
      description: "Search for bars and restaurants that may have happy hours near a location. Use this when the user provides a location (ZIP code, city, or coordinates) and wants to find happy hour spots.",
      input_schema: {
        type: "object",
        properties: {
          location: {
            type: "string",
            description: "The location to search near - can be a ZIP code, city name, or 'lat,lng' coordinates"
          },
          radius_miles: {
            type: "number",
            description: "Search radius in miles. Defaults to 5 if not specified."
          },
          limit: {
            type: "integer",
            description: "Maximum number of results to return. Defaults to 5."
          }
        },
        required: ["location"]
      }
    },
    {
      name: "get_place_details",
      description: "Get detailed information about a specific venue including hours, website, phone number, and ratings. Use this after search_happy_hours to get more details about a specific place.",
      input_schema: {
        type: "object",
        properties: {
          place_id: {
            type: "string",
            description: "The Google Places ID of the venue"
          }
        },
        required: ["place_id"]
      }
    },
    {
      name: "check_website_for_happy_hour",
      description: "Fetch a venue's website and check if it mentions happy hour deals. Use this to verify if a venue actually has happy hour specials. Only use on restaurant/bar websites, not search engines or directories.",
      input_schema: {
        type: "object",
        properties: {
          url: {
            type: "string",
            description: "The full URL of the venue's website to check (e.g., https://example.com/menu)"
          }
        },
        required: ["url"]
      }
    },
    {
      name: "web_search_happy_hour",
      description: "Search the web for happy hour information about a venue or in a location. Use this when you need to find happy hour details that aren't on the venue's main website, or to discover venues with happy hours in an area.",
      input_schema: {
        type: "object",
        properties: {
          venue_name: {
            type: "string",
            description: "The name of a specific venue to search for (optional if searching by location only)"
          },
          location: {
            type: "string", 
            description: "The city/area to search in (e.g., 'Bernardsville NJ', 'Summit NJ')"
          }
        },
        required: ["location"]
      }
    },
    {
      name: "deep_scan_venue_website",
      description: "Thoroughly scan a venue's website including common happy hour pages like /happy-hour, /specials, /menu. Use this when check_website_for_happy_hour didn't find happy hour on the main page but you want to check other pages.",
      input_schema: {
        type: "object",
        properties: {
          base_url: {
            type: "string",
            description: "The base URL of the venue's website (e.g., https://example.com)"
          }
        },
        required: ["base_url"]
      }
    }
  ].freeze

  SYSTEM_PROMPT = <<~PROMPT
    You are a friendly happy hour finder. Find VERIFIED happy hour deals efficiently.

    TOOLS (use sparingly - max 3-4 calls total):
    1. web_search_happy_hour - BEST first step. Searches web for happy hours in an area.
    2. check_website_for_happy_hour - Verify a specific URL has happy hour info.
    3. search_happy_hours - Find nearby venues via Google Places (backup option).
    4. get_place_details - Get venue website/details (only if needed).

    EFFICIENT WORKFLOW:
    1. If no location, ask for it (ZIP, city, or coordinates).
    2. Call web_search_happy_hour for the location - this returns venues WITH happy hour mentions.
    3. For the TOP 2 results that mention happy hour, call check_website_for_happy_hour on their URLs.
    4. Present results showing venue name, times, deals, and website link.
    
    EFFICIENCY RULES:
    - Limit to 2-3 venues max per response
    - Don't use deep_scan unless specifically needed
    - Web search usually finds happy hour pages directly - verify those first
    - Stop once you have 2 good verified results

    RESPONSE FORMAT (use this exact style for clean chat display):
    
    For each venue, format like this:
    
    **🍸 [Venue Name]**
    📍 [Address/Location]
    🕐 [Happy Hour Times]
    🍹 [Deals: list the specials]
    🔗 [View Menu](url)
    
    Keep it compact. Use emoji sparingly. One blank line between venues.
    End with a brief friendly note if helpful.

    BOUNDARIES:
    - Only help with happy hours. Politely decline other topics.
    - Never make up details - only report what tools find.
    - Only show VERIFIED results (found_happy_hour: true)
  PROMPT

  def initialize
    @client = Anthropic::Client.new(
      api_key: ENV.fetch("ANTHROPIC_API_KEY")
    )
  end

  def chat(messages)
    conversation_messages = messages.map do |msg|
      { role: msg[:role].to_s, content: msg[:content].to_s }
    end

    turns = 0
    total_input_tokens = 0
    total_output_tokens = 0

    loop do
      turns += 1
      if turns > MAX_CONVERSATION_TURNS
        log_token_usage(turns, total_input_tokens, total_output_tokens)
        return { 
          response: "I've hit my processing limit for this request. Please try again with a simpler query.",
          tool_calls: [],
          token_usage: { input: total_input_tokens, output: total_output_tokens, total: total_input_tokens + total_output_tokens }
        }
      end

      response = @client.messages.create(
        model: "claude-sonnet-4-20250514",
        max_tokens: MAX_OUTPUT_TOKENS,
        system: SYSTEM_PROMPT,
        tools: TOOLS,
        messages: conversation_messages
      )

      # Track token usage
      if response.usage
        total_input_tokens += response.usage.input_tokens || 0
        total_output_tokens += response.usage.output_tokens || 0
        Rails.logger.info("[TOKEN] Turn #{turns}: +#{response.usage.input_tokens} input, +#{response.usage.output_tokens} output")
      end

      if response.stop_reason.to_s == "tool_use"
        tool_uses = response.content.select { |block| block.type.to_s == "tool_use" }
        
        tool_results = tool_uses.map do |tool_use|
          result = execute_tool(tool_use.name, tool_use.input)
          {
            type: "tool_result",
            tool_use_id: tool_use.id,
            content: truncate_result(result.to_json)
          }
        end

        conversation_messages << { role: "assistant", content: serialize_content(response.content) }
        conversation_messages << { role: "user", content: tool_results }
      else
        text_response = response.content.find { |block| block.type.to_s == "text" }&.text || ""
        log_token_usage(turns, total_input_tokens, total_output_tokens)
        return {
          response: text_response,
          tool_calls: extract_tool_calls(conversation_messages),
          token_usage: { input: total_input_tokens, output: total_output_tokens, total: total_input_tokens + total_output_tokens }
        }
      end
    end
  end

  def log_token_usage(turns, input_tokens, output_tokens)
    total = input_tokens + output_tokens
    # Anthropic pricing for claude-sonnet-4-20250514: $3/MTok input, $15/MTok output
    cost_input = (input_tokens / 1_000_000.0) * 3.0
    cost_output = (output_tokens / 1_000_000.0) * 15.0
    total_cost = cost_input + cost_output
    
    Rails.logger.info("=" * 50)
    Rails.logger.info("[TOKEN SUMMARY]")
    Rails.logger.info("  Turns: #{turns}")
    Rails.logger.info("  Input tokens: #{input_tokens}")
    Rails.logger.info("  Output tokens: #{output_tokens}")
    Rails.logger.info("  Total tokens: #{total}")
    Rails.logger.info("  Estimated cost: $#{'%.6f' % total_cost}")
    Rails.logger.info("=" * 50)
  end

  private

  def execute_tool(name, input)
    input = input.transform_keys(&:to_s) if input.is_a?(Hash)
    
    case name
    when "search_happy_hours"
      GooglePlacesService.new.search_happy_hours(
        location: input["location"],
        radius_miles: input["radius_miles"] || 5,
        limit: input["limit"] || 5
      )
    when "get_place_details"
      GooglePlacesService.new.get_place_details(
        place_id: input["place_id"]
      )
    when "check_website_for_happy_hour"
      WebScraperService.new.fetch_happy_hour_info(
        url: input["url"]
      )
    when "web_search_happy_hour"
      WebScraperService.new.search_for_happy_hour(
        venue_name: input["venue_name"] || "",
        location: input["location"]
      )
    when "deep_scan_venue_website"
      WebScraperService.new.deep_scan_venue(
        base_url: input["base_url"]
      )
    else
      { error: "Unknown tool: #{name}" }
    end
  rescue StandardError => e
    Rails.logger.error("Tool execution error: #{e.message}")
    { error: "Failed to execute tool: #{e.message}" }
  end

  def truncate_result(json_string)
    if json_string.length > MAX_TOOL_RESULT_LENGTH
      json_string[0...MAX_TOOL_RESULT_LENGTH] + '... [truncated]'
    else
      json_string
    end
  end

  def serialize_content(content)
    content.map do |block|
      case block.type.to_s
      when "text"
        { type: "text", text: block.text }
      when "tool_use"
        { type: "tool_use", id: block.id, name: block.name, input: block.input }
      else
        { type: block.type.to_s }
      end
    end
  end

  def extract_tool_calls(messages)
    tool_calls = []
    messages.each do |m|
      next unless m[:role] == "assistant"
      content = m[:content]
      next unless content.is_a?(Array)
      
      content.each do |block|
        if block.is_a?(Hash) && block[:type] == "tool_use"
          tool_calls << { name: block[:name], input: block[:input] }
        elsif block.respond_to?(:type) && block.type.to_s == "tool_use"
          tool_calls << { name: block.name, input: block.input }
        end
      end
    end
    tool_calls
  end
end
