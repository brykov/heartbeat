module HeartbeatOOP
  class Implementation

    VIDEO_ONLINE_TTL_SECONDS = (ENV['VIDEO_ONLINE_TTL_SECONDS'] || 5).to_i
    STALE_DATA_TTL_SECONDS   = (ENV['STALE_DATA_TTL_SECONDS'] || 60).to_i

    def initialize(address, port, config, status, logger)
      @pings = []
      @request_counter = []

      # expose a reference to self into global status hash
      status[:hb_interface] = self
    end

    def run
      EM.add_periodic_timer(STALE_DATA_TTL_SECONDS) do

        rotten_index = @pings.rindex{|ping|ping.rotten?}
        @pings.slice! 0..rotten_index unless rotten_index.nil?

        threshold = Time.new.to_i - STALE_DATA_TTL_SECONDS
        stale_index = @request_counter.rindex{|timestamp| timestamp < threshold}
        @request_counter.slice!(0..stale_index) unless stale_index.nil?

        GC.start
      end
    end

    def ping(app_id, customer_id, video_id)
      log_request
      @pings << Ping.new(app_id, customer_id, video_id)
    end

    def number_of_videos(app_id, customer_id)
      log_request
      # TODO: optimize to count only fresh right subset of @pings
      @pings.count {|ping| ping.fresh? && ping.belongs_to?(app_id, customer_id: customer_id) }
    end

    def number_of_viewers(app_id, video_id)
      log_request
      # TODO: optimize to count only fresh right subset of @pings
      @pings.count {|ping| ping.fresh? && ping.belongs_to?(app_id, video_id: video_id) }
    end

    def number_of_requests
      log_request
      threshold = Time.new.to_i - STALE_DATA_TTL_SECONDS
      stale_index = @request_counter.rindex{|timestamp| timestamp < threshold}
      @request_counter.size - stale_index.to_i
    end

    private

    def log_request
      @request_counter << Time.new.to_i
    end

  end


  class Ping

    def initialize(app_id, customer_id, video_id)
      @app_id = app_id
      @customer_id = customer_id
      @video_id = video_id
      @timestamp = Time.new.to_i
      @becomes_rotten_on = @timestamp + VIDEO_ONLINE_TTL_SECONDS
    end

    def rotten?
      @becomes_rotten_on <= Time.new.to_i
    end

    def fresh?
      !rotten?
    end

    def belongs_to?(app_id, options = {})
      options = {customer_id: @customer_id, video_id: @video_id}.merge options
      return false unless @app_id==app_id
      return false unless @customer_id==options[:customer_id]
      return false unless @video_id==options[:video_id]
      true
    end

  end
end
