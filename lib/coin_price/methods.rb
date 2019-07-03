module CoinPrice
  class << self
    # value is just a wrapper for values.
    def value(base = 'BTC', quote = 'USD', source_id = config.default_source, options = { from_cache: false })
      values([base], [quote], source_id, options)[base][quote]
    end

    # timestamp is just a wrapper for timestamps.
    def timestamp(base = 'BTC', quote = 'USD', source_id = config.default_source)
      timestamps([base], [quote], source_id)[base][quote]
    end

    def values(bases = ['BTC'], quotes = ['USD'], source_id = config.default_source, options = { from_cache: false })
      source = find_source_klass(source_id)
      Fetch.new(bases, quotes, source, options).values
    end

    def timestamps(bases = ['BTC'], quotes = ['USD'], source_id = config.default_source)
      source = find_source_klass(source_id)
      Fetch.new(bases, quotes, source).timestamps
    end

    def requests_count(source_id = CoinPrice.config.default_source)
      source = find_source_klass(source_id)
      source.new.requests_count
    end

    def find_source_klass(id)
      AVAILABLE_SOURCES[id] || (raise UnknownSourceError, id)
    end

    def cache_key
      "#{config.cache_key_prefix}coin-price"
    end
  end
end
