class GooglePlacesService
  PLACES_BASE_URL = "https://places.googleapis.com/v1/places"
  GEOCODE_BASE_URL = "https://maps.googleapis.com/maps/api/geocode/json"

  def initialize
    key = ENV.fetch("GOOGLE_PLACES_API_KEY", nil)
    @api_key = key.present? && !key.include?("your_") ? key : nil
  end

  def search_happy_hours(location:, radius_miles: 5, limit: 5)
    return { error: "Location is required" } if location.blank?
    return mock_search_results(location, limit) if @api_key.blank?

    coords = geocode_location(location)
    return { error: "Could not find location: #{location}" } unless coords

    search_nearby_bars(coords, radius_miles, limit)
  rescue HTTParty::Error, StandardError => e
    Rails.logger.error("Google Places search error: #{e.message}")
    { error: "Search failed: #{e.message}" }
  end

  def get_place_details(place_id:)
    # Check if this is a demo place_id
    return mock_place_details(place_id) if place_id&.start_with?("demo_")
    return mock_place_details(place_id) if @api_key.blank?

    result = fetch_place_details(place_id)
    
    # If real API fails, try to find in demo data or return error with helpful info
    if result[:error]
      Rails.logger.warn("Real API failed, checking demo data for: #{place_id}")
      { error: result[:error], suggestion: "Enable 'Places API (New)' in Google Cloud Console" }
    else
      result
    end
  rescue HTTParty::Error, StandardError => e
    Rails.logger.error("Google Places details error: #{e.message}")
    { error: "Failed to get details: #{e.message}" }
  end

  def text_search_venue(query:)
    return { results: [] } if @api_key.blank?

    body = {
      textQuery: query,
      maxResultCount: 1
    }

    response = HTTParty.post(
      "#{PLACES_BASE_URL}:searchText",
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => @api_key,
        "X-Goog-FieldMask" => "places.id,places.displayName,places.formattedAddress,places.rating,places.websiteUri,places.location"
      },
      body: body.to_json
    )

    unless response.success?
      Rails.logger.warn("Text search failed for '#{query}': #{response.code}")
      return { results: [] }
    end

    places = response["places"] || []
    { results: places.map { |p| format_place_result(p) } }
  rescue StandardError => e
    Rails.logger.error("Text search error: #{e.message}")
    { results: [] }
  end

  def geocode(location)
    return nil if location.blank?
    geocode_location(location)
  end

  private

  def geocode_location(location)
    if location.match?(/^-?\d+\.?\d*,\s*-?\d+\.?\d*$/)
      lat, lng = location.split(",").map(&:strip).map(&:to_f)
      return { lat: lat, lng: lng }
    end

    response = HTTParty.get(
      GEOCODE_BASE_URL,
      query: { address: location, key: @api_key }
    )

    return nil unless response.success? && response["status"] == "OK"

    geo = response["results"].first&.dig("geometry", "location")
    geo ? { lat: geo["lat"], lng: geo["lng"] } : nil
  end

  def search_nearby_bars(coords, radius_miles, limit)
    # Convert radius to approximate lat/lng delta for bounding box
    # 1 degree latitude ≈ 69 miles, 1 degree longitude varies by latitude
    lat_delta = radius_miles / 69.0
    lng_delta = radius_miles / (69.0 * Math.cos(coords[:lat] * Math::PI / 180))

    # Use Text Search with locationRestriction (rectangle) to strictly limit results
    body = {
      textQuery: "happy hour specials",
      maxResultCount: 20,
      locationRestriction: {
        rectangle: {
          low: { 
            latitude: coords[:lat] - lat_delta, 
            longitude: coords[:lng] - lng_delta 
          },
          high: { 
            latitude: coords[:lat] + lat_delta, 
            longitude: coords[:lng] + lng_delta 
          }
        }
      }
    }

    response = HTTParty.post(
      "#{PLACES_BASE_URL}:searchText",
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => @api_key,
        "X-Goog-FieldMask" => "places.id,places.displayName,places.formattedAddress,places.rating,places.userRatingCount,places.priceLevel,places.types,places.primaryType,places.websiteUri,places.location"
      },
      body: body.to_json
    )

    unless response.success?
      Rails.logger.error("Places API error: #{response.code} - #{response.body}")
      return { error: "Places API error: #{response.code}" }
    end

    places = response["places"] || []
    Rails.logger.info("Text Search found #{places.length} places for 'happy hour specials'")

    {
      status: "ok",
      location_searched: "#{coords[:lat]}, #{coords[:lng]}",
      results: places.map { |place| format_place_result(place) }
    }
  end

  def fetch_place_details(place_id)
    # PLACES_BASE_URL already ends with /places, so just append the ID
    clean_id = place_id.gsub(/^places\//, "")

    response = HTTParty.get(
      "#{PLACES_BASE_URL}/#{clean_id}",
      headers: {
        "X-Goog-Api-Key" => @api_key,
        "X-Goog-FieldMask" => "id,displayName,formattedAddress,nationalPhoneNumber,websiteUri,rating,userRatingCount,currentOpeningHours,priceLevel,types,primaryType,location"
      }
    )

    unless response.success?
      Rails.logger.error("Place details error: #{response.code} - #{response.body}")
      return { error: "Failed to get place details: #{response.code}" }
    end

    format_place_details(response.parsed_response)
  end

  def format_place_result(place)
    location = place["location"]
    {
      place_id: place["id"]&.gsub("places/", ""),
      name: place.dig("displayName", "text"),
      address: place["formattedAddress"],
      rating: place["rating"],
      total_ratings: place["userRatingCount"],
      price_level: format_price_level(place["priceLevel"]),
      types: place["types"],
      primary_type: place["primaryType"],
      website: place["websiteUri"],
      location: location ? { lat: location["latitude"], lng: location["longitude"] } : nil,
      happy_hour_hint: infer_happy_hour_hint(place)
    }
  end

  def format_place_details(place)
    location = place["location"]
    {
      place_id: place["id"]&.gsub("places/", ""),
      name: place.dig("displayName", "text"),
      address: place["formattedAddress"],
      phone: place["nationalPhoneNumber"],
      website: place["websiteUri"],
      rating: place["rating"],
      total_ratings: place["userRatingCount"],
      price_level: format_price_level(place["priceLevel"]),
      hours: format_hours(place["currentOpeningHours"]),
      types: place["types"],
      location: location ? { lat: location["latitude"], lng: location["longitude"] } : nil,
      happy_hour_note: "Check website or call for happy hour times - many bars have happy hour 3-7pm weekdays"
    }
  end

  def format_price_level(level)
    case level
    when "PRICE_LEVEL_FREE" then 0
    when "PRICE_LEVEL_INEXPENSIVE" then 1
    when "PRICE_LEVEL_MODERATE" then 2
    when "PRICE_LEVEL_EXPENSIVE" then 3
    when "PRICE_LEVEL_VERY_EXPENSIVE" then 4
    else nil
    end
  end

  def format_hours(opening_hours)
    return nil unless opening_hours

    weekday_descriptions = opening_hours["weekdayDescriptions"]
    return nil unless weekday_descriptions

    days = %w[monday tuesday wednesday thursday friday saturday sunday]
    hours = {}

    weekday_descriptions.each_with_index do |desc, idx|
      day_name = days[idx] || "day_#{idx}"
      time_part = desc.split(": ", 2).last
      hours[day_name] = time_part
    end

    hours
  end

  def infer_happy_hour_hint(place)
    types = place["types"] || []
    primary = place["primaryType"]

    if types.include?("bar") || primary == "bar"
      "Likely has happy hour (bar)"
    elsif types.include?("night_club")
      "May have drink specials"
    elsif types.include?("restaurant")
      "May have happy hour - call to confirm"
    else
      nil
    end
  end

  # Real NJ venues with verified happy hour pages for demo purposes
  DEMO_VENUES = [
    {
      place_id: "demo_osteria_morini",
      name: "Osteria Morini",
      address: "107 Morristown Rd, Bernardsville, NJ 07924",
      rating: 4.6,
      total_ratings: 407,
      price_level: 3,
      types: ["bar", "restaurant", "italian_restaurant"],
      happy_hour_hint: "Likely has happy hour (bar)",
      phone: "(908) 221-0040",
      website: "https://osteriamorini.com/bernardsville-nj/menus/happy-hour/"
    },
    {
      place_id: "demo_washington_house",
      name: "Washington House Restaurant",
      address: "55 S Finley Ave, Basking Ridge, NJ 07920",
      rating: 4.5,
      total_ratings: 832,
      price_level: 2,
      types: ["bar", "restaurant", "american_restaurant"],
      happy_hour_hint: "Likely has happy hour (bar)",
      phone: "(908) 766-7610",
      website: "https://www.washingtonhouserestaurant.com/"
    },
    {
      place_id: "demo_delicious_heights",
      name: "Delicious Heights",
      address: "428 Springfield Ave, Berkeley Heights, NJ 07922",
      rating: 4.3,
      total_ratings: 866,
      price_level: 2,
      types: ["bar", "restaurant"],
      happy_hour_hint: "Likely has happy hour (bar)",
      phone: "(908) 464-3287",
      website: "https://deliciousheights.com/"
    }
  ].freeze

  def mock_search_results(location, limit)
    {
      status: "demo_mode",
      note: "Using demo venues with real websites to demonstrate happy hour verification.",
      location_searched: location,
      results: DEMO_VENUES.first(limit).map do |v|
        {
          place_id: v[:place_id],
          name: v[:name],
          address: v[:address],
          rating: v[:rating],
          total_ratings: v[:total_ratings],
          price_level: v[:price_level],
          types: v[:types],
          happy_hour_hint: v[:happy_hour_hint]
        }
      end
    }
  end

  def mock_place_details(place_id)
    venue = DEMO_VENUES.find { |v| v[:place_id] == place_id }
    
    if venue
      {
        status: "demo_mode",
        place_id: venue[:place_id],
        name: venue[:name],
        address: venue[:address],
        phone: venue[:phone],
        website: venue[:website],
        rating: venue[:rating],
        total_ratings: venue[:total_ratings],
        price_level: venue[:price_level],
        types: venue[:types]
      }
    else
      {
        status: "demo_mode",
        error: "Venue not found in demo data",
        place_id: place_id
      }
    end
  end
end
