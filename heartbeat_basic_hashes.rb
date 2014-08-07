module HeartbeatBasicHashes

  class Implementation

    VIDEO_ONLINE_TTL_SECONDS = (ENV['VIDEO_ONLINE_TTL_SECONDS'] || 5).to_i
    STALE_DATA_TTL_SECONDS   = (ENV['STALE_DATA_TTL_SECONDS'] || 60).to_i

    def initialize(address, port, config, status, logger)
      @app_customer_videos  = {}
      @app_videos           = {}
      @request_counter      = []

      # expose a reference to self into global status hash
      status[:hb_interface] = self
    end

    def run
      EM.add_periodic_timer(STALE_DATA_TTL_SECONDS) do

        _app_videos         = {}
        threshold_timestamp = Time.new.to_i - VIDEO_ONLINE_TTL_SECONDS

        @app_customer_videos.each do |app_id, customers|
          customers.keys.each do |customer_id|
            @app_customer_videos[app_id][customer_id].reject! do |video_id, video_timestamp|
              if video_timestamp < threshold_timestamp
                # delete stale reference
                true
              else
                # count video per customer
                _app_videos[app_id]           ||= {}
                _app_videos[app_id][video_id] ||= 0
                _app_videos[app_id][video_id] += 1

                # don't delete reference
                false
              end
            end
            @app_customer_videos[app_id].delete(customer_id) if @app_customer_videos[app_id][customer_id].empty?
          end
        end
        @app_customer_videos.delete_if { |app_id, app| app.empty? }

        @app_videos = _app_videos

        threshold = Time.new.to_i - STALE_DATA_TTL_SECONDS
        stale_index = @request_counter.rindex{|timestamp| timestamp < threshold}
        @request_counter.slice!(0..stale_index) unless stale_index.nil?

        GC.start
      end
    end

    def ping(app_id, customer_id, video_id)
      log_request
      @app_customer_videos[app_id]                        ||= {}
      @app_customer_videos[app_id][customer_id]           ||= {}
      @app_customer_videos[app_id][customer_id][video_id] = Time.new.to_i
    end

    def number_of_videos(app_id, customer_id)
      log_request
      threshold_timestamp = Time.new.to_i - VIDEO_ONLINE_TTL_SECONDS
      @app_customer_videos[app_id][customer_id].select { |video_id, video_timestamp| video_timestamp >= threshold_timestamp }.size rescue nil
    end

    def number_of_viewers(app_id, video_id)
      log_request
      @app_videos[app_id][video_id] rescue nil
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

end
