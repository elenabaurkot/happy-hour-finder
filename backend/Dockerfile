FROM ruby:3.2.2

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Set production environment
ENV RAILS_ENV=production
ENV BUNDLE_WITHOUT="development:test"

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle install

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Start server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
