require 'rubygems'
require 'bundler/setup'
require 'goliath'
require 'grape'
require_relative 'heartbeat_basic_hashes'
require_relative 'heartbeat_oop'
require 'pp'

Bundler.setup
Bundler.require

p Goliath.env

class Heartbeat < Grape::API

  version 'v1', :using => :path
  format :json

  helpers do
    def hb
      env.status[:hb_interface]
    end
  end

  resource 'heartbeat' do

    params do
      requires :app_id, type: String
      requires :customer_id, type: String
      requires :video_id, type: String
    end
    post :ping do
      hb.ping params[:app_id], params[:customer_id], params[:video_id]
      { ok: true }
    end

    params do
      requires :app_id, type: String
      requires :customer_id, type: String
    end
    get :number_of_videos do
      { number_of_videos: hb.number_of_videos(params[:app_id], params[:customer_id]) }
    end

    params do
      requires :app_id, type: String
      requires :video_id, type: String
    end
    get :number_of_viewers do
      { number_of_viewers: hb.number_of_viewers(params[:app_id], params[:video_id]) }
    end

    get :throughput do
      { number_of_requests: hb.number_of_requests }
    end


  end

end

$implementation_module = ENV['IMPLEMENTATION'].constantize rescue HeartbeatBasicHashes

class Application < Goliath::API

  use Rack::Reloader
  plugin $implementation_module::Implementation

  def response(env)
    begin
      ::Heartbeat.call(env)
    rescue Exception => e
      pp e.backtrace
      raise e
    end
  end

end
