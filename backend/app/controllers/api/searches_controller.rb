module Api
  class SearchesController < ApplicationController
    def create
      location = params[:location]&.strip
      radius_miles = (params[:radius_miles] || 5).to_i
      limit = (params[:limit] || 5).to_i
      offset = (params[:offset] || 0).to_i

      if location.blank?
        return render json: { error: "Location is required" }, status: :bad_request
      end

      begin
        result = HappyHourSearchService.new.search(
          location: location,
          radius_miles: radius_miles,
          limit: limit,
          offset: offset
        )

        render json: result
      rescue StandardError => e
        Rails.logger.error("Search error: #{e.message}")
        render json: { error: "Search failed. Please try again." }, status: :internal_server_error
      end
    end
  end
end
