class HappyHourSearchService
  MAX_VENUES_TO_CHECK = 10

  def search(location:, radius_miles:, limit:, offset:)
    venues = find_venues(location, radius_miles)
    
    if venues.empty?
      return {
        results: [],
        total_found: 0,
        has_more: false,
        location: location,
        radius_miles: radius_miles,
        message: "No venues found in this area. Try expanding your search radius."
      }
    end

    verified_venues = verify_happy_hours(venues)
    
    total_found = verified_venues.length
    paginated = verified_venues.drop(offset).take(limit)
    has_more = (offset + limit) < total_found

    formatted = format_results(paginated, location, radius_miles, total_found, has_more)

    {
      results: paginated,
      formatted_results: formatted,
      total_found: total_found,
      showing: paginated.length,
      offset: offset,
      has_more: has_more,
      location: location,
      radius_miles: radius_miles
    }
  end

  private

  AGGREGATOR_PATTERNS = [
    /\d+\s*(of the)?\s*best/i,        # "19 Of The Best", "10 best"
    /top\s*\d+/i,                      # "Top 10"
    /best\s*\d+/i,                     # "Best 15"
    /\byelp\b/i,                       # Yelp
    /\btripadvisor\b/i,               # TripAdvisor
    /\bopentable\b/i,                 # OpenTable
    /\bthrillist\b/i,                 # Thrillist
    /\beater\b/i,                     # Eater
    /\btimeout\b/i,                   # Time Out
    /places\s*to/i,                   # "places to drink"
    /where\s*to/i,                    # "where to find"
    /guide\s*to/i,                    # "guide to"
    /search\s*all/i,                  # "Search All Happy Hours"
    /\bbot\b/i,                       # Bot verification pages
    /\bverification\b/i,              # Verification pages
    /\bcaptcha\b/i,                   # Captcha pages
    /\bcloudflare\b/i,                # Cloudflare blocks
    /access\s*denied/i,               # Access denied pages
    /skip\s*to\s*content/i,           # Generic page headers
  ].freeze

  def find_venues(location, radius_miles)
    venues = []

    web_results = WebScraperService.new.search_for_happy_hour(
      venue_name: "",
      location: location
    )

    if web_results[:results_with_happy_hour].present?
      web_results[:results_with_happy_hour].each do |result|
        name = extract_venue_name(result[:title])
        url = result[:url].to_s
        
        # Skip aggregator/listicle results
        next if is_aggregator?(name, url)
        
        venues << {
          name: name,
          source: "web_search",
          url: result[:url],
          snippet: result[:snippet]
        }
      end
    end

    places_results = GooglePlacesService.new.search_happy_hours(
      location: location,
      radius_miles: radius_miles,
      limit: MAX_VENUES_TO_CHECK
    )

    if places_results[:results].present?
      places_results[:results].each do |place|
        venues << {
          name: place[:name],
          address: place[:address],
          place_id: place[:place_id],
          rating: place[:rating],
          source: "google_places"
        }
      end
    end

    venues.uniq { |v| v[:name]&.downcase&.gsub(/[^a-z]/, '') }.take(MAX_VENUES_TO_CHECK)
  end

  def is_aggregator?(name, url)
    # Check name for aggregator patterns
    return true if AGGREGATOR_PATTERNS.any? { |pattern| name =~ pattern }
    
    # Check URL for known aggregator domains
    aggregator_domains = %w[yelp.com tripadvisor.com opentable.com thrillist.com 
                            eater.com timeout.com infatuation.com zagat.com
                            bestthingsxx.com foursquare.com]
    return true if aggregator_domains.any? { |domain| url.include?(domain) }
    
    false
  end

  def verify_happy_hours(venues)
    verified = []
    places_service = GooglePlacesService.new

    venues.each do |venue|
      website_url = venue[:url]

      # Always try to get details from Google Places for better address info
      if venue[:place_id]
        details = places_service.get_place_details(place_id: venue[:place_id])
        website_url ||= details[:website]
        venue[:address] = details[:address] if details[:address].present?
        venue[:phone] = details[:phone] if details[:phone].present?
        venue[:rating] = details[:rating] if details[:rating].present?
      elsif venue[:name].present? && venue[:address].blank?
        # Try to find address by searching for the venue name
        search_result = places_service.search_happy_hours(
          location: venue[:name],
          radius_miles: 1,
          limit: 1
        )
        if search_result[:results]&.first
          found = search_result[:results].first
          venue[:address] = found[:address] if found[:address].present?
          venue[:place_id] = found[:place_id]
          
          # Get more details
          if found[:place_id]
            details = places_service.get_place_details(place_id: found[:place_id])
            website_url ||= details[:website]
            venue[:address] ||= details[:address]
            venue[:phone] = details[:phone]
            venue[:rating] = details[:rating]
          end
        end
      end

      next unless website_url.present?

      scrape_result = WebScraperService.new.deep_scan_venue(base_url: website_url)
      
      if scrape_result[:found_on].present?
        venue[:happy_hour_verified] = true
        venue[:happy_hour_url] = scrape_result[:found_on]
        venue[:happy_hour_details] = scrape_result[:details][:relevant_text]
        venue[:confidence] = scrape_result[:details][:confidence]
        
        # Only include venues with verified addresses (so we know they're in radius)
        if venue[:address].present?
          verified << venue
        else
          Rails.logger.info("Skipping #{venue[:name]} - no address to verify location")
        end
      elsif scrape_result.dig(:details, :found_happy_hour)
        venue[:happy_hour_verified] = true
        venue[:happy_hour_url] = website_url
        venue[:happy_hour_details] = scrape_result[:details][:relevant_text]
        venue[:confidence] = scrape_result[:details][:confidence]
        
        # Only include venues with verified addresses
        if venue[:address].present?
          verified << venue
        else
          Rails.logger.info("Skipping #{venue[:name]} - no address to verify location")
        end
      end

      break if verified.length >= MAX_VENUES_TO_CHECK
    end

    verified
  end

  def extract_venue_name(title)
    title.to_s
      .gsub(/\s*[-–|].*$/, '')
      .gsub(/happy hour/i, '')
      .gsub(/menu/i, '')
      .gsub(/specials/i, '')
      .strip
  end

  def format_results(venues, location, radius_miles, total_found, has_more)
    return nil if venues.empty?

    client = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
    
    venue_data = venues.map do |v|
      {
        name: v[:name],
        address: v[:address],
        happy_hour_details: v[:happy_hour_details],
        url: v[:happy_hour_url],
        rating: v[:rating],
        phone: v[:phone]
      }
    end

    display_location = location.include?(',') ? "your location" : "ZIP #{location}"

    prompt = <<~PROMPT
      You are a friendly happy hour expert. Format these #{venues.length} verified happy hour venues into a helpful response.
      
      Location: #{display_location} (#{radius_miles} mile radius)
      Total venues found: #{total_found}

      VENUE DATA:
      #{venue_data.to_json}

      INSTRUCTIONS:
      1. Start with a brief friendly intro line about finding happy hours near their location
      
      2. For each venue, format EXACTLY like this (each emoji on its own line):
      
      **🍸 Venue Name**
      📍 Full address
      🕐 Days and times (e.g., "Monday-Friday 4-7pm")
      🍹 Deals (e.g., "$5 margaritas, half-price appetizers")
      ⭐ 4.5/5 rating
      📞 Phone number if available
      🔗 [View Menu](url)
      
      3. Parse the happy_hour_details carefully to extract days, times, and specific deals/prices.
      
      4. Put a blank line between each venue for readability.
      
      5. End with a brief friendly note.
      
      IMPORTANT: Each detail MUST be on its own line. Do not combine multiple emojis on one line.
      Use the details provided - don't make up information not in the data.
    PROMPT

    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 800,
      messages: [{ role: "user", content: prompt }]
    )

    response.content.find { |b| b.type.to_s == "text" }&.text || ""
  rescue StandardError => e
    Rails.logger.error("Format error: #{e.message}")
    nil
  end
end
