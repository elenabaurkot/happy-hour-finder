class WebScraperService
  MAX_CONTENT_LENGTH = 8000
  TIMEOUT_SECONDS = 10

  HAPPY_HOUR_KEYWORDS = [
    "happy hour",
    "happyhour", 
    "drink special",
    "food special",
    "half price",
    "half-price",
    "2 for 1",
    "two for one",
    "$2 off",
    "$3 off",
    "$4 off",
    "$5 off",
    "discounted drinks",
    "bar menu",
    "late night menu",
    "daily specials",
    "weekday specials",
    "cocktail specials"
  ].freeze

  HAPPY_HOUR_PATHS = [
    "/happy-hour",
    "/happyhour", 
    "/menus/happy-hour",
    "/menu/happy-hour",
    "/specials",
    "/bar-menu",
    "/drinks"
  ].freeze

  def fetch_happy_hour_info(url:, try_subpages: false)
    return { error: "URL is required" } if url.blank?
    return { error: "Invalid URL format" } unless valid_url?(url)

    response = HTTParty.get(
      url,
      timeout: TIMEOUT_SECONDS,
      headers: {
        "User-Agent" => "Mozilla/5.0 (compatible; HappyHourFinder/1.0)",
        "Accept" => "text/html"
      },
      follow_redirects: true
    )

    unless response.success?
      return { error: "Failed to fetch page: HTTP #{response.code}" }
    end

    content_type = response.headers["content-type"] || ""
    unless content_type.include?("text/html")
      return { error: "Page is not HTML content" }
    end

    html = response.body
    text_content = extract_text(html)
    happy_hour_info = find_happy_hour_info(text_content)

    {
      url: url,
      found_happy_hour: happy_hour_info[:found],
      confidence: happy_hour_info[:confidence],
      relevant_text: happy_hour_info[:relevant_text],
      keywords_found: happy_hour_info[:keywords_found]
    }
  rescue HTTParty::TimeoutError
    { error: "Request timed out after #{TIMEOUT_SECONDS} seconds" }
  rescue HTTParty::Error, StandardError => e
    Rails.logger.error("Web scraper error: #{e.message}")
    { error: "Failed to fetch page: #{e.message}" }
  end

  def search_for_happy_hour(venue_name:, location:)
    query = "#{venue_name} #{location} happy hour menu specials"
    encoded_query = CGI.escape(query)
    
    search_url = "https://html.duckduckgo.com/html/?q=#{encoded_query}"
    
    response = HTTParty.get(
      search_url,
      timeout: TIMEOUT_SECONDS,
      headers: {
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept" => "text/html"
      }
    )

    unless response.success?
      return { error: "Search failed: HTTP #{response.code}" }
    end

    doc = Nokogiri::HTML(response.body)
    results = []

    doc.css(".result").first(15).each do |result|
      title = result.css(".result__title")&.text&.strip
      snippet = result.css(".result__snippet")&.text&.strip
      link = result.css(".result__url")&.text&.strip

      next if title.blank? || link.blank?

      has_happy_hour_mention = HAPPY_HOUR_KEYWORDS.any? do |kw|
        (title + " " + snippet.to_s).downcase.include?(kw.downcase)
      end

      results << {
        title: title,
        snippet: snippet,
        url: link.start_with?("http") ? link : "https://#{link}",
        mentions_happy_hour: has_happy_hour_mention
      }
    end

    {
      query: query,
      results: results,
      results_with_happy_hour: results.select { |r| r[:mentions_happy_hour] }
    }
  rescue StandardError => e
    Rails.logger.error("Web search error: #{e.message}")
    { error: "Search failed: #{e.message}" }
  end

  def deep_scan_venue(base_url:)
    results = []
    
    main_result = fetch_happy_hour_info(url: base_url)
    results << { url: base_url, result: main_result }
    
    return { found_on: base_url, details: main_result } if main_result[:found_happy_hour]
    
    uri = URI.parse(base_url)
    base = "#{uri.scheme}://#{uri.host}"
    
    HAPPY_HOUR_PATHS.each do |path|
      full_url = "#{base}#{path}"
      next if full_url == base_url
      
      path_result = fetch_happy_hour_info(url: full_url)
      results << { url: full_url, result: path_result }
      
      if path_result[:found_happy_hour]
        return { found_on: full_url, details: path_result }
      end
    end
    
    { found_on: nil, details: main_result, pages_checked: results.length }
  rescue StandardError => e
    { error: e.message }
  end

  private

  def valid_url?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  def extract_text(html)
    doc = Nokogiri::HTML(html)
    
    doc.css("script, style, nav, header, footer, aside").remove
    
    text = doc.css("body").text
    text = text.gsub(/\s+/, " ").strip
    
    text[0...MAX_CONTENT_LENGTH]
  end

  def find_happy_hour_info(text)
    text_lower = text.downcase
    keywords_found = []
    relevant_snippets = []

    HAPPY_HOUR_KEYWORDS.each do |keyword|
      if text_lower.include?(keyword.downcase)
        keywords_found << keyword
        
        index = text_lower.index(keyword.downcase)
        if index
          # Start from the keyword itself or a bit before if at start of sentence
          # Look backwards for a sentence boundary (. ! ? or start of text)
          search_start = [index - 100, 0].max
          prefix_text = text[search_start...index]
          
          # Find the last sentence boundary before the keyword
          sentence_start = prefix_text.rindex(/[.!?]\s+/)
          if sentence_start
            start_pos = search_start + sentence_start + 2  # Skip the punctuation and space
          else
            start_pos = search_start
          end
          
          end_pos = [index + keyword.length + 200, text.length].min
          snippet = text[start_pos...end_pos].strip
          
          # Clean up leading whitespace/punctuation but preserve first letter
          snippet = snippet.gsub(/^[\s\-–—:,;]+/, '')
          
          # Only add ellipsis at end if truncated
          snippet = "#{snippet}..." if end_pos < text.length && !snippet.end_with?('...')
          
          relevant_snippets << snippet if snippet.present?
        end
      end
    end

    if keywords_found.any?
      confidence = case keywords_found.length
                   when 1 then "low"
                   when 2..3 then "medium"
                   else "high"
                   end

      {
        found: true,
        confidence: confidence,
        keywords_found: keywords_found.uniq,
        relevant_text: relevant_snippets.first(3).join("\n\n")
      }
    else
      {
        found: false,
        confidence: "none",
        keywords_found: [],
        relevant_text: "No happy hour information found on this page."
      }
    end
  end
end
