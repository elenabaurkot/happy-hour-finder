Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow localhost for development and Vercel for production
    origins "http://localhost:3001", 
            "http://localhost:5173", 
            "http://127.0.0.1:5173",
            /\Ahttps:\/\/.*\.vercel\.app\z/,
            /\Ahttps:\/\/.*\.railway\.app\z/

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
