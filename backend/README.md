# Happy Hour Finder - Backend

Rails API backend for the Happy Hour Finder application. Uses Claude (Anthropic) for AI-powered tool calling and Google Places API for venue search.

## Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Copy environment variables:
   ```bash
   cp .env.example .env
   ```

3. Add your API keys to `.env`:
   - `ANTHROPIC_API_KEY` - Get from [Anthropic Console](https://console.anthropic.com/)
   - `GOOGLE_PLACES_API_KEY` - Get from [Google Cloud Console](https://console.cloud.google.com/)

4. Start the server:
   ```bash
   rails server -p 3000
   ```

## API Endpoints

- `GET /api/health` - Health check
- `POST /api/chat` - Chat endpoint (coming in next todo)

## Architecture

- `app/services/` - Business logic (Anthropic, Google Places)
- `app/controllers/api/` - API endpoints
- `config/initializers/rack_attack.rb` - Rate limiting (10 req/min per IP)
- `config/initializers/cors.rb` - CORS for frontend
