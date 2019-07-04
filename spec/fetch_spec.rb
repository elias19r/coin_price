require 'spec_helper'

describe CoinPrice::Fetch do
  let(:bases)  { ['XXX', 'YYY'] }
  let(:quotes) { ['AAA', 'XXX'] }

  let(:source_id) { 'any-source-id' }
  class AnySource < CoinPrice::Source; end
  let(:source) { AnySource }
  let(:fetch) { CoinPrice::Fetch.new(bases, quotes, source) }

  let(:values) do
    {
      bases[0] => {
        quotes[0] => 9101.42.to_d,
        quotes[1] => 1.to_d
      },
      bases[1] => {
        quotes[0] => 202.42.to_d,
        quotes[1] => 0.022.to_d
      }
    }
  end

  let(:timestamp) { 1562180583 }
  let(:timestamps) do
    {
      bases[0] => {
        quotes[0] => timestamp,
        quotes[1] => timestamp
      },
      bases[1] => {
        quotes[0] => timestamp,
        quotes[1] => timestamp
      }
    }
  end

  before do
    allow(fetch.source).to receive(:id).and_return(source_id)
  end

  describe '#values' do
    context 'with "from_cache: true" option' do
      let(:options) do
        { from_cache: true }
      end
      let(:fetch) { CoinPrice::Fetch.new(bases, quotes, source, options) }

      context 'when some cached value is missing' do
        it 'raises CoinPrice::CacheError' do
          expect do
            fetch.values
          end.to raise_error(CoinPrice::CacheError)
        end
      end

      context 'when no cached value is missing' do
        before do
          allow(fetch).to receive(:read_cached_values).and_return(values)
        end

        it 'calls read_cached_values' do
          expect(fetch).to receive(:read_cached_values).once

          fetch.values
        end

        it 'returns values read from cache' do
          expect(fetch.values).to eq(values)
        end
      end
    end

    context 'with "from_cache: false" option' do
      let(:options) do
        { from_cache: false }
      end
      let(:fetch) { CoinPrice::Fetch.new(bases, quotes, source, options) }

      before do
        allow(fetch.source).to receive(:values).with(bases, quotes).and_return(values)

        allow(fetch).to receive(:timestamps=).with(any_args).and_return(fetch.timestamps = timestamp)
      end

      it 'calls source#values' do
        expect(fetch.source).to receive(:values).with(bases, quotes).once

        fetch.values
      end

      it 'returns fetched values from Source' do
        expect(fetch.values).to eq(values)
      end

      it 'caches values in Redis' do
        fetch.values

        expect(CoinPrice.redis.get(fetch.cache_key_value(bases[0], quotes[0]))).to \
          eq(values[bases[0]][quotes[0]].to_s)
        expect(CoinPrice.redis.get(fetch.cache_key_value(bases[0], quotes[1]))).to \
          eq(values[bases[0]][quotes[1]].to_s)

        expect(CoinPrice.redis.get(fetch.cache_key_value(bases[1], quotes[0]))).to \
          eq(values[bases[1]][quotes[0]].to_s)
        expect(CoinPrice.redis.get(fetch.cache_key_value(bases[1], quotes[1]))).to \
          eq(values[bases[1]][quotes[1]].to_s)
      end

      it 'saves timestamps in Redis' do
        fetch.values

        expect(CoinPrice.redis.get(fetch.cache_key_timestamp(bases[0], quotes[0]))).to \
          eq(timestamp.to_s)
        expect(CoinPrice.redis.get(fetch.cache_key_timestamp(bases[0], quotes[1]))).to \
          eq(timestamp.to_s)

        expect(CoinPrice.redis.get(fetch.cache_key_timestamp(bases[1], quotes[0]))).to \
          eq(timestamp.to_s)
        expect(CoinPrice.redis.get(fetch.cache_key_timestamp(bases[1], quotes[1]))).to \
          eq(timestamp.to_s)
      end
    end
  end

  describe '#values=' do
    it 'writes values to Redis for each base/quote pair' do
      expect(CoinPrice.redis).to \
        receive(:set).with(fetch.cache_key_value(bases[0], quotes[0]), values[bases[0]][quotes[0]]).once
      expect(CoinPrice.redis).to \
        receive(:set).with(fetch.cache_key_value(bases[0], quotes[1]), values[bases[0]][quotes[1]]).once

      expect(CoinPrice.redis).to \
        receive(:set).with(fetch.cache_key_value(bases[1], quotes[0]), values[bases[1]][quotes[0]]).once
      expect(CoinPrice.redis).to \
        receive(:set).with(fetch.cache_key_value(bases[1], quotes[1]), values[bases[1]][quotes[1]]).once

      fetch.values = values
    end
  end

  describe '#timestamps' do
    it 'reads timestamps from Redis for each base/quote pair' do
      expect(CoinPrice.redis).to \
        receive(:get).with(fetch.cache_key_timestamp(bases[0], quotes[0])).once
      expect(CoinPrice.redis).to \
        receive(:get).with(fetch.cache_key_timestamp(bases[0], quotes[1])).once

      expect(CoinPrice.redis).to \
        receive(:get).with(fetch.cache_key_timestamp(bases[1], quotes[0])).once
      expect(CoinPrice.redis).to \
        receive(:get).with(fetch.cache_key_timestamp(bases[1], quotes[1])).once

      fetch.timestamps
    end

    it 'returns timestamps read from Redis' do
      CoinPrice.redis.set(fetch.cache_key_timestamp(bases[0], quotes[0]), timestamp)
      CoinPrice.redis.set(fetch.cache_key_timestamp(bases[0], quotes[1]), timestamp)

      CoinPrice.redis.set(fetch.cache_key_timestamp(bases[1], quotes[0]), timestamp)
      CoinPrice.redis.set(fetch.cache_key_timestamp(bases[1], quotes[1]), timestamp)

      expect(fetch.timestamps).to eq(timestamps)
    end
  end

  describe '#timestamps=' do
    it 'writes the same timestamp to Redis for each base/quote pair' do
      expect(CoinPrice.redis).to \
        receive(:set).with(fetch.cache_key_timestamp(bases[0], quotes[0]), timestamp).once
      expect(CoinPrice.redis).to \
        receive(:set).with(fetch.cache_key_timestamp(bases[0], quotes[1]), timestamp).once

      expect(CoinPrice.redis).to \
        receive(:set).with(fetch.cache_key_timestamp(bases[1], quotes[0]), timestamp).once
      expect(CoinPrice.redis).to \
        receive(:set).with(fetch.cache_key_timestamp(bases[1], quotes[1]), timestamp).once

      fetch.timestamps = timestamp
    end
  end

  describe '#cache_key_value' do
    let(:base) { 'XXX' }
    let(:quote) { 'YYY' }

    it {
      expect(fetch.cache_key_value(base, quote)).to \
        eq("#{fetch.source.cache_key}:value:#{base}:#{quote}")
    }
  end

  describe '#cache_key_timestamp' do
    let(:base) { 'XXX' }
    let(:quote) { 'YYY' }

    it {
      expect(fetch.cache_key_timestamp(base, quote)).to \
        eq("#{fetch.source.cache_key}:timestamp:#{base}:#{quote}")
    }
  end

  describe '#read_cached_values' do
    context 'when some cached value is missing' do
      it 'raises CoinPrice::CacheError' do
        expect do
          fetch.read_cached_values
        end.to raise_error(CoinPrice::CacheError)
      end
    end

    context 'when no cached values is missing' do
      before do
        CoinPrice.redis.set(fetch.cache_key_value(bases[0], quotes[0]), values[bases[0]][quotes[0]])
        CoinPrice.redis.set(fetch.cache_key_value(bases[0], quotes[1]), values[bases[0]][quotes[1]])

        CoinPrice.redis.set(fetch.cache_key_value(bases[1], quotes[0]), values[bases[1]][quotes[0]])
        CoinPrice.redis.set(fetch.cache_key_value(bases[1], quotes[1]), values[bases[1]][quotes[1]])
      end

      it 'reads values from Redis for each base/quote pair' do
        expect(CoinPrice.redis).to \
          receive(:get).with(fetch.cache_key_value(bases[0], quotes[0])).once.and_call_original
        expect(CoinPrice.redis).to \
          receive(:get).with(fetch.cache_key_value(bases[0], quotes[1])).once.and_call_original

        expect(CoinPrice.redis).to \
          receive(:get).with(fetch.cache_key_value(bases[1], quotes[0])).once.and_call_original
        expect(CoinPrice.redis).to \
          receive(:get).with(fetch.cache_key_value(bases[1], quotes[1])).once.and_call_original

        fetch.read_cached_values
      end
    end
  end
end