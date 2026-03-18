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
    return mock_place_details(place_id) if @api_key.blank?

    fetch_place_details(place_id)
  rescue HTTParty::Error, StandardError => e
    Rails.logger.error("Google Places details error: #{e.message}")
    { error: "Failed to get details: #{e.message}" }
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
    radius_meters = (radius_miles * 1609.34).to_i

    body = {
      includedTypes: ["bar", "restaurant", "night_club"],
      maxResultCount: [limit, 20].min,
      locationRestriction: {
        circle: {
          center: { latitude: coords[:lat], longitude: coords[:lng] },
          radius: radius_meters.to_f
        }
      }
    }

    response = HTTParty.post(
      "#{PLACES_BASE_URL}:searchNearby",
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => @api_key,
        "X-Goog-FieldMask" => "places.id,places.displayName,places.formattedAddress,places.rating,places.userRatingCount,places.priceLevel,places.types,places.primaryType"
      },
      body: body.to_json
    )

    unless response.success?
      Rails.logger.error("Places API error: #{response.code} - #{response.body}")
      return { error: "Places API error: #{response.code}" }
    end

    places = response["places"] || []

    {
      status: "ok",
      location_searched: "#{coords[:lat]}, #{coords[:lng]}",
      results: places.map { |place| format_place_result(place) }
    }
  end

  def fetch_place_details(place_id)
    formatted_id = place_id.start_with?("places/") ? place_id : "places/#{place_id}"

    response = HTTParty.get(
      "#{PLACES_BASE_URL}/#{formatted_id}",
      headers: {
        "X-Goog-Api-Key" => @api_key,
        "X-Goog-FieldMask" => "id,displayName,formattedAddress,nationalPhoneNumber,websiteUri,rating,userRatingCount,currentOpeningHours,priceLevel,types,primaryType"
      }
    )

    unless response.success?
      Rails.logger.error("Place details error: #{response.code} - #{response.body}")
      return { error: "Failed to get place details: #{response.code}" }
    end

    format_place_details(response.parsed_response)
  end

  def format_place_result(place)
    {
      place_id: place["id"]&.gsub("places/", ""),
      name: place.dig("displayName", "text"),
      address: place["formattedAddress"],
      rating: place["rating"],
      total_ratings: place["userRatingCount"],
      price_level: format_price_level(place["priceLevel"]),
      types: place["types"],
      primary_type: place["primaryType"],
      happy_hour_hint: infer_happy_hour_hint(place)
    }
  end

  def format_place_details(place)
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

  def mock_search_results(location, limit)
    {
      status: "mock_data",
      warning: "⚠️ DEMO MODE: No Google Places API key configured. These are fake example results, not real venues. Set GOOGLE_PLACES_API_KEY environment variable for real search results.",
      location_searched: location,
      results: [
        {
          place_id: "mock_place_1",
          name: "The Happy Hour Spot",
          address: "123 Main St, #{location}",
          rating: 4.5,
          total_ratings: 234,
          price_level: 2,
          types: ["bar", "restaurant"],
          happy_hour_hint: "Likely has happy hour (bar)"
        },
        {
          place_id: "mock_place_2",
          name: "Sunset Bar & Grill",
          address: "456 Oak Ave, #{location}",
          rating: 4.2,
          total_ratings: 187,
          price_level: 2,
          types: ["bar", "restaurant"],
          happy_hour_hint: "Likely has happy hour (bar)"
        },
        {
          place_id: "mock_place_3",
          name: "Downtown Tavern",
          address: "789 Elm St, #{location}",
          rating: 4.0,
          total_ratings: 156,
          price_level: 1,
          types: ["bar"],
          happy_hour_hint: "Likely has happy hour (bar)"
        }
      ].first(limit)
    }
  end

  def mock_place_details(place_id)
    {
      status: "mock_data",
      warning: "⚠️ DEMO MODE: This is fake example data, not a real venue. Set GOOGLE_PLACES_API_KEY for real results.",
      place_id: place_id,
      name: "Mock Venue (Example)",
      address: "123 Example St",
      phone: "(555) 123-4567",
      website: "https://example.com",
      rating: 4.5,
      total_ratings: 150,
      price_level: 2,
      hours: {
        "monday" => "11:00 AM - 10:00 PM",
        "tuesday" => "11:00 AM - 10:00 PM",
        "wednesday" => "11:00 AM - 10:00 PM",
        "thursday" => "11:00 AM - 11:00 PM",
        "friday" => "11:00 AM - 12:00 AM",
        "saturday" => "12:00 PM - 12:00 AM",
        "sunday" => "12:00 PM - 9:00 PM"
      },
      happy_hour_note: "Check website or call for happy hour times - many bars have happy hour 3-7pm weekdays"
    }
  end
end
