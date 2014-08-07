require 'bundler'

Bundler.setup
Bundler.require

require 'goliath/test_helper'

Goliath.env = :test

RSpec.configure do |c|
  c.include Goliath::TestHelper
end

# reduce timeouts for testing purposes
VIDEO_ONLINE_TTL_SECONDS = 3
ENV['VIDEO_ONLINE_TTL_SECONDS'] = VIDEO_ONLINE_TTL_SECONDS.to_s
STALE_DATA_TTL_SECONDS = 7
ENV['STALE_DATA_TTL_SECONDS'] = STALE_DATA_TTL_SECONDS.to_s

require_relative 'server'


# a hack to prevent TestHelper from stopping the server after the first request
# which implies explicit EM.stop_event_loop call in the last request callback
module Goliath
  module TestHelper
    def stop
      nil
    end
  end
end

describe Application do
  let(:err) do
    Proc.new do |em|
      fail "API request failed: #{em.error}"
    end
  end

  def ping(app_id, customer_id, video_id, &blk)
    options = {
      path: '/v1/heartbeat/ping',
      body: {app_id: app_id, customer_id: customer_id, video_id: video_id}
    }
    post_request(options, err, &blk)
  end

  def number_of_videos(app_id, customer_id, &blk)
    options = {
      path: '/v1/heartbeat/number_of_videos',
      query: {app_id: app_id, customer_id: customer_id}
    }
    get_request(options, err, &blk)
  end

  def number_of_viewers(app_id, video_id, &blk)
    options = {
      path: '/v1/heartbeat/number_of_viewers',
      query: {app_id: app_id, video_id: video_id}
    }
    get_request(options, err, &blk)
  end

  def number_of_requests(&blk)
    options = {
      path: '/v1/heartbeat/throughput'
    }
    get_request(options, err, &blk)
  end



  it 'accepts a ping request and responds with {"ok":true}', :t1 do
    with_api(Application) do

      ping('app1', 'customer1', 'video1') do |req|
        expect(MultiJson.load(req.response)).to eq({'ok' => true})
        EM.stop_event_loop
      end

    end
  end


  it 'returns the number of videos per customer/app pair', :t2 do
    with_api(Application) do

      ping('app1', 'customer1', 'video1')

      number_of_videos('app1', 'customer1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 1})
      end

      ping('app1', 'customer1', 'video2')
      ping('app2', 'customer1', 'video1')
      ping('app1', 'customer2', 'video1')


      number_of_videos('app1', 'customer1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 2})
      end

      number_of_videos('app1', 'customer1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 2})
      end

      number_of_videos('app2', 'customer1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 1})
      end

      number_of_videos('app1', 'customer2') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 1})
      end

      number_of_videos('app1', 'customer3') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => nil}).or eq({'number_of_videos' => 0})
        EM.stop_event_loop
      end

    end

  end

  it 'does not count video per app/customer after VIDEO_ONLINE_TTL_SECONDS seconds', :t3 do
    with_api(Application) do
      ping('app1', 'customer1', 'video1')
      sleep 2
      ping('app1', 'customer1', 'video2')

      number_of_videos('app1', 'customer1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 2})
      end

      sleep 2

      number_of_videos('app1', 'customer1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 1})
      end

      sleep 2

      number_of_videos('app1', 'customer1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 0})
        EM.stop_event_loop
      end

    end
  end


  it 'calculates amount of viewers per app/video and removes stale data every STALE_DATA_TTL_SECONDS seconds', :t4 do
    with_api(Application) do
      sleep 6
      ping('app1', 'customer1', 'video1')
      ping('app1', 'customer2', 'video1')
      ping('app1', 'customer3', 'video1')
      ping('app2', 'customer1', 'video1') # different app

      sleep 2

      number_of_viewers('app1', 'video1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_viewers' => 3})
      end

      sleep 7

      number_of_viewers('app1', 'video1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_viewers' => nil}).or eq({'number_of_viewers' => 0})
      end

      number_of_videos('app1', 'customer1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_videos' => nil}).or eq({'number_of_videos' => 0})
        EM.stop_event_loop
      end


    end
  end

  it 'it tracks number of requests for STALE_DATA_TTL_SECONDS seconds', :t5 do
    with_api(Application) do
      sleep 6
      (1..100).each do |i|
        ping('app1', 'customer%d'%i, 'video1')
        number_of_videos('app1', 'customer%d'%i) do |req|
          expect(MultiJson.load(req.response)).to eq({'number_of_videos' => 1})
        end

      end
      sleep 2
      number_of_viewers('app1', 'video1') do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_viewers' => 100})
      end

      number_of_requests do |req|
        expect(MultiJson.load(req.response)).to eq({'number_of_requests' => 202})
        EM.stop_event_loop
      end

    end
  end

end
