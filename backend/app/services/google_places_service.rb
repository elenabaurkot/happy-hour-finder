class GooglePlacesService
  BASE_URL = "https://maps.googleapis.com/maps/api/place"

  def initialize
    @api_key = ENV.fetch("GOOGLE_PLACES_API_KEY", nil)
  end

  def search_happy_hours(location:, radius_miles: 5, limit: 5)
    if @api_key.blank?
      return mock_search_results(location, limit)
    end

    # Real implementation coming in Todo 3
    # For now, return mock data to test the tool-calling flow
    mock_search_results(location, limit)
  end

  def get_place_details(place_id:)
    if @api_key.blank?
      return mock_place_details(place_id)
    end

    # Real implementation coming in Todo 3
    mock_place_details(place_id)
  end

  private

  def mock_search_results(location, limit)
    {
      status: "mock_data",
      message: "Using mock data - set GOOGLE_PLACES_API_KEY for real results",
      location_searched: location,
      results: [
        {
          place_id: "mock_place_1",
          name: "The Happy Hour Spot",
          address: "123 Main St, #{location}",
          rating: 4.5,
          price_level: 2,
          types: ["bar", "restaurant"],
          happy_hour_hint: "Likely has happy hour (bar)"
        },
        {
          place_id: "mock_place_2", 
          name: "Sunset Bar & Grill",
          address: "456 Oak Ave, #{location}",
          rating: 4.2,
          price_level: 2,
          types: ["bar", "restaurant"],
          happy_hour_hint: "Likely has happy hour (bar)"
        },
        {
          place_id: "mock_place_3",
          name: "Downtown Tavern",
          address: "789 Elm St, #{location}",
          rating: 4.0,
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
      place_id: place_id,
      name: "Mock Venue",
      address: "123 Example St",
      phone: "(555) 123-4567",
      website: "https://example.com",
      rating: 4.5,
      total_ratings: 150,
      hours: {
        monday: "11:00 AM - 10:00 PM",
        tuesday: "11:00 AM - 10:00 PM",
        wednesday: "11:00 AM - 10:00 PM",
        thursday: "11:00 AM - 11:00 PM",
        friday: "11:00 AM - 12:00 AM",
        saturday: "12:00 PM - 12:00 AM",
        sunday: "12:00 PM - 9:00 PM"
      },
      happy_hour_note: "Check website or call for happy hour times"
    }
  end
end
