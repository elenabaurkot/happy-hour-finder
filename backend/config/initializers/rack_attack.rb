class Rack::Attack
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle("api/ip", limit: 10, period: 60) do |req|
    req.ip if req.path.start_with?("/api/chat")
  end

  self.throttled_responder = lambda do |_req|
    [
      429,
      { "Content-Type" => "application/json" },
      [{ error: "Rate limit exceeded. Please wait a moment." }.to_json]
    ]
  end
end
