$LOAD_PATH.unshift File.join(File.dirname(__FILE__))
require 'boot'
require 'sinatra/base'
require 'async_sinatra'
require 'fileutils'

module Wallop
  class App < Sinatra::Base
    #register Sinatra::Reloader if RACK_ENV == 'development'
    register Sinatra::Async
    enable :logging
    use Rack::CommonLogger, Wallop.logger
    set :bind, '0.0.0.0'
    set :port, Wallop.config['port']

    configure do
      mime_type :m3u8, 'application/x-mpegURL'
      mime_type :ts, 'video/MP2T'
    end

    before do
      Wallop.request_host = request.host
      content_type :json
    end

    get '/' do
      redirect '/channels?type=favorites'
    end

    post '/channels/favorites' do
      Wallop.add_favorite_channel(params[:channel])
      JSON.dump({:status => 200, :message => 'ok'})
    end

    delete '/channels/favorites' do
      Wallop.remove_favorite_channel(params[:channel])
      JSON.dump({:status => 200, :message => 'ok'})
    end

    get '/channels' do
      case params[:type]
      when /hd/i
        @channels = Wallop.hd_lineup
      when /favorites/i
        @channels = Wallop.favorite_lineup
      else
        @channels = Wallop.lineup
      end

      if request.accept && request.accept?('text/html')
        content_type :html
        erb :channels
      else
        JSON.dump({:channels => @channels})
      end
    end

    post '/channels/:channel/tune' do
      resolution = params[:resolution] || '1280x720'
      bitrate = params[:bitrate] || '3000k'

      channel = params[:channel]

      if !Wallop.sessions.has_key?(channel)
        Wallop.tune(channel, resolution, bitrate)
      end

      JSON.dump({:status => 200, :message => 'ok'})
    end

    get '/channels/:channel/status' do
      session = Wallop.sessions[params[:channel]]
      halt 404 if !session

      JSON.dump(session)
    end

    post '/channels/:channel/stop' do
      session = Wallop.sessions[params[:channel]]
      halt 404 if !session

      Wallop.logger.info "MANUALLY STOPPING SESSION - #{session[:channel]} - #{session[:pid]}"
      if Process.kill('QUIT', session[:pid])
        Process::waitpid(session[:pid]) rescue nil
        Wallop.cleanup_channel(session[:channel])
        Wallop.sessions.delete(session[:channel])
      end

      JSON.dump({:status => 200, :message => 'ok'})
    end

    get '/channels/:channel/raw' do
      redirect Wallop.raw_stream_url_for_channel(params[:channel])
    end

    get '/channels/:channel.m3u8' do
      redirect "/channels/#{channel}/live.m3u8"
    end
    
    get '/channels/:channel/live.m3u8' do
      content_type :m3u8

      session = Wallop.sessions[params[:channel]]
      halt 404 if !session

      halt 420 if !session[:ready]

      session[:last_read] = Time.now

      send_file(Wallop.playlist_file_path(session[:channel]))
    end

    get %r{/channels/(\d+)/(live\d+.ts)} do
      content_type :ts
      send_file(File.join(Wallop.channel_transcoding_path(params[:captures][0]), params[:captures][1]))
    end

    aget '/channels/:channel.:timestamp.png' do
      Wallop.snapshot(params[:channel], params[:width]) do |file|
        async_schedule{ cache_control :no_cache; redirect "/snapshots/#{file}" }
        EM.add_timer(60){ FileUtils.rm_f "app/public/snapshots/#{file}" }
      end
    end

    get '/channels/:channel.png' do
      redirect "/channels/#{params[:channel]}.#{Time.now.to_i}.png?width=#{params[:width]}"
    end

    get '/channels/:channel' do
      content_type :html

      @channel = params[:channel]
      erb :channel
    end


  end
end

EM.next_tick do
  EventMachine.add_periodic_timer(0.5) { Wallop.sweep_sessions }
  EventMachine.add_periodic_timer(1) { DVR.record }
end

Wallop::App.run!(:Port => Wallop.config['port'])
