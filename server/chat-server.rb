#!/usr/bin/env ruby
require 'sinatra'
require 'sinatra-websocket'
require 'json'
require 'cgi' # for CGI.escapeHTML

set :server, 'thin'

class Client
  def initialize(socket = nil, username = nil)
    @socket   = socket
    @username = username
    @channel  = nil
  end
  def socket=(socket)
    @socket ||= socket
  end
  def socket
    @socket
  end
  def username=(username)
    @username ||= username
  end
  def username
    @username
  end
  def channel=(channel)
    @channel = channel
  end
  def channel
    @channel
  end
  def send(msg)
    @socket.send(msg)
  end
end

class Channel
  def initialize(name)
    @name = name
    @clients ||= []
  end
  def name=(name)
    @name = name
  end
  def name
    @name
  end
  def join(client)
    @clients << client
    client.channel = self.name

    send(client, 'join')
    # warn("[JOIN] #{client.username} joined #{@name}")
  end
  def part(client)
    send(client, 'part')
    client.channel = nil
    @clients.delete(client)
    # warn("[PART] #{client.username} left #{@name}")
  end
  def chat(sender, message)
    # warn("[CHAT] <#{sender.username}> #{message}")
    send(sender, 'msg', message)
  end
  def send(sender, event, payload=nil)
    warn("[#{@name}:#{event}] <#{sender.username}> #{payload}")
    @clients.each do |client|
      payload = (CGI.escapeHTML(payload) unless payload.nil?)
      client.send({sender: sender.username, event: event, payload: payload}.to_json)
    end
  end
end

class World
  def initialize
    @clients  ||= []
    @channels ||= {}
  end
  def add_client(client)
    @clients << client
    client.send({sender: 'SYSTEM', event: 'connect', payload: "Connected to pixChat v0"}.to_json)
  end
  def remove_client(client)
    @channels[client.channel].part(client) unless client.channel.nil?
    @clients.delete(client)
    warn("<- [SOCK] socket closed (#{client.username}), #{connected_count} connected")
  end
  def connected_count
    @clients.count
  end
  def find_client(websocket)
    @clients.each do |client|
      return client if client.socket == websocket
    end
  end
  def parse(socket, data)
    # warn("received: #{data}")
    data = JSON.parse(data)
    client = find_client(socket)

    case data['event']
      when "join"
        client.username = data['username'] #hack
        @channels[client.channel].part(client) unless client.channel.nil?
        @channels[data['channel']] ||= Channel.new(data['channel'])
        @channels[data['channel']].join client
        # warn("[DEBUG] new channel: #{client.channel}")

      when "part"
        @channels[data['channel']].part(client) unless client.channel.nil?

      when "msg"
        # warn("[DEBUG] current channel: #{client.channel}")
        @channels[client.channel].chat(client, data['msg'])
    end
  end
end

$world = World.new

get '/' do
  return unless request.websocket?
  request.websocket do |ws|
    ws.onopen do
      begin
        $world.add_client Client.new(ws)
        warn("-> [SOCK] socket connected, #{$world.connected_count} connected")
      rescue Exception => e
        warn("1_CAUGHT EXCEPTION: #{e}")
      end
    end
    ws.onmessage do |data|
      EM.next_tick {
        begin
          $world.parse ws, data
        rescue Exception => e
          warn("2_CAUGHT EXCEPTION: #{e}")
        end
      }
    end
    ws.onclose do
      begin
        $world.remove_client($world.find_client(ws))
      rescue Exception => e
        warn("3_CAUGHT EXCEPTION: #{e}")
      end
    end
  end
end