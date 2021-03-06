module CoinPrice
  module CoinMarketCap
    class Source < CoinPrice::Source
      def id
        @id ||= 'coinmarketcap'
      end

      def name
        @name ||= 'CoinMarketCap'
      end

      def website
        @website ||= 'https://coinmarketcap.com/'
      end

      def notes
        @notes ||= 'API Key is required'
      end

      def values(bases = ['BTC'], quotes = ['USD'])
        if bases.one? && quotes.one?
          fetch_conversion(bases.first, quotes.first)
        else
          fetch_listings(bases, quotes)
        end
      end

      private

      def fetch_conversion(base, quote)
        response = API.request(API.url_conversion(base, quote))
        incr_requests_count

        { base => { quote => find_value(base, quote, response&.dig('data')) } }
      end

      def fetch_listings(bases, quotes)
        responses = request_listings(quotes)

        bases.product(quotes).each_with_object({}) do |pair, result|
          base, quote = pair
          data = find_coin(base, quote, responses)

          result[base] ||= {}
          result[base][quote] = find_value(base, quote, data)
        end
      end

      def request_listings(quotes)
        quotes.each_with_object({}) do |quote, responses|
          sleep CoinMarketCap.config.wait_between_requests

          responses[quote] = API.request(API.url_listings(quote))
          incr_requests_count
        end
      end

      def find_value(base, quote, data)
        data.dig('quote', quote, 'price')&.to_d ||
          data.dig('quote', API::COIN_ID[quote].to_s, 'price')&.to_d ||
          (raise CoinPrice::ValueNotFoundError, "#{base}/#{quote}")
      end

      def find_coin(base, quote, responses)
        responses[quote]&.dig('data')&.find { |item| item&.dig('id') == API::COIN_ID[base] } ||
          (raise CoinPrice::ValueNotFoundError, "#{base}/#{quote}")
      end
    end
  end
end
