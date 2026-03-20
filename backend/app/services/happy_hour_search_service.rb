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

    verified_venues = verify_happy_hours(venues, location)
    
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

  def address_matches_location?(address, search_location)
    return false if address.blank?
    
    address_lower = address.downcase
    
    # Extract state from address (look for 2-letter state code or full state name)
    address_state = extract_state_from_address(address_lower)
    
    # If searching by coordinates, we trust Google Places filtering
    if search_location.match?(/^-?\d+\.\d+,\s*-?\d+\.\d+$/)
      return true
    end
    
    # If searching by ZIP code, look up what state that ZIP is in
    if search_location.match?(/^\d{5}$/)
      search_state = state_for_zip(search_location)
      if search_state && address_state
        return search_state == address_state
      end
      # If we can't determine states, allow it
      return true
    end
    
    # If searching by city/state format, extract and compare
    if search_location.match?(/,\s*([A-Z]{2})\b/i)
      search_state = search_location.match(/,\s*([A-Z]{2})\b/i)&.[](1)&.downcase
      if search_state && address_state
        return search_state == address_state
      end
    end
    
    true  # Default to allowing if we can't determine
  end

  def extract_state_from_address(address)
    # Match 2-letter state code (usually before ZIP)
    state_match = address.match(/\b([a-z]{2})\s+\d{5}/)
    return state_match[1] if state_match
    
    # Match state code after comma
    state_match = address.match(/,\s*([a-z]{2})\b/)
    return state_match[1] if state_match
    
    nil
  end

  def state_for_zip(zip)
    prefix = zip[0..2].to_i
    
    case prefix
    when 100..149 then 'ny'
    when 150..196 then 'pa'
    when 197..199 then 'de'
    when 200..205 then 'dc'
    when 206..219 then 'md'
    when 220..246 then 'va'
    when 247..268 then 'wv'
    when 270..289 then 'nc'
    when 290..299 then 'sc'
    when 300..319 then 'ga'
    when 320..339 then 'fl'
    when 350..369 then 'al'
    when 370..385 then 'tn'
    when 386..397 then 'ms'
    when 400..427 then 'ky'
    when 430..459 then 'oh'
    when 460..479 then 'in'
    when 480..499 then 'mi'
    when 500..528 then 'ia'
    when 530..549 then 'wi'
    when 550..567 then 'mn'
    when 570..577 then 'sd'
    when 580..588 then 'nd'
    when 590..599 then 'mt'
    when 600..629 then 'il'
    when 630..658 then 'mo'
    when 660..679 then 'ks'
    when 680..693 then 'ne'
    when 700..714 then 'la'
    when 716..729 then 'ar'
    when 730..749 then 'ok'
    when 750..799 then 'tx'
    when 800..816 then 'co'
    when 820..831 then 'wy'
    when 832..838 then 'id'
    when 840..847 then 'ut'
    when 850..865 then 'az'
    when 870..884 then 'nm'
    when 889..898 then 'nv'
    when 900..961 then 'ca'
    when 967..968 then 'hi'
    when 970..979 then 'or'
    when 980..994 then 'wa'
    when 995..999 then 'ak'
    when 10..69 then 'ma' # 010-069
    when 70..89 then 'nj' # 070-089
    when 90..99 then 'ct' # Overlap with other states, simplified
    else nil
    end
  end

  def verify_happy_hours(venues, search_location)
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
        
        # Only include venues with verified addresses in the right area
        if venue[:address].present? && address_matches_location?(venue[:address], search_location)
          verified << venue
        else
          Rails.logger.info("Skipping #{venue[:name]} - address '#{venue[:address]}' doesn't match location '#{search_location}'")
        end
      elsif scrape_result.dig(:details, :found_happy_hour)
        venue[:happy_hour_verified] = true
        venue[:happy_hour_url] = website_url
        venue[:happy_hour_details] = scrape_result[:details][:relevant_text]
        venue[:confidence] = scrape_result[:details][:confidence]
        
        # Only include venues with verified addresses in the right area
        if venue[:address].present? && address_matches_location?(venue[:address], search_location)
          verified << venue
        else
          Rails.logger.info("Skipping #{venue[:name]} - address '#{venue[:address]}' doesn't match location '#{search_location}'")
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
      Format these happy hour venues. Location: #{display_location} (#{radius_miles} miles).

      DATA:
      #{venue_data.to_json}

      FORMAT RULES - FOLLOW EXACTLY:
      
      Start with one friendly intro sentence.
      
      Then for EACH venue, use this EXACT format with LINE BREAKS after each line:
      
      ## 🍸 Venue Name
      
      📍 Address here
      
      🕐 Days and times here
      
      🍹 Deals and prices here
      
      ⭐ Rating here
      
      📞 Phone here
      
      🔗 [View Menu](url)
      
      ---
      
      (next venue)
      
      End with one friendly closing sentence.
      
      CRITICAL: Put each emoji detail on its OWN LINE with a blank line between them.
      Extract specific times and prices from happy_hour_details. Don't make up info.
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
