# frozen_string_literal: true

class RedisConfiguration
  class << self
    def establish_pool(new_pool_size)
      @pool&.shutdown(&:close)
      @pool = ConnectionPool.new(size: new_pool_size) { new.connection }
    end

    delegate :with, to: :pool

    def pool
      @pool ||= establish_pool(pool_size)
    end

    def pool_size
      if Sidekiq.server?
        Sidekiq[:concurrency]
      else
        ENV['MAX_THREADS'] || 5
      end
    end
  end

  def connection
    if namespace?
      Redis::Namespace.new(namespace, redis: raw_connection)
    else
      raw_connection
    end
  end

  def namespace?
    namespace.present?
  end

  def namespace
    ENV.fetch('REDIS_NAMESPACE', nil)
  end

  def url
    ENV['REDIS_URL']
  end

  def sentinels
    ENV.fetch('REDIS_SENTINELS', nil)
  end

  def sentinels_master
    ENV.fetch('REDIS_MASTER_NAME', 'mymaster')
  end

  private

  def raw_connection
    if sentinels
      Redis.new(host: sentinels_master, name: sentinels_master, sentinels: sentinels.split(',').map do |pair|
        key, value = pair.split(':')
        { host: key, port: value.to_i }
      end, driver: :hiredis)
    else
      Redis.new(url: url, driver: :hiredis)
    end
  end
end
