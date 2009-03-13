require 'socket'

module Sprinkles
  class Bot
    attr_accessor :nickname

    def initialize(options = {})
      options.each do |option, value|
        instance_variable_set("@#{option}", value)
      end
      @processors = []
      @request_processors = []
      @response_processors = []
      @hostname = Socket.gethostname
      @server ||= { :hostname => "localhost", :port => 6667 }
      add_request_processor(Sprinkles::Processor::Ping.new)
    end

    def start
      connect
      authenticate
      loop do
        @buffer ||= ""
        @buffer += @socket.recv(1024)
        messages = @buffer.split(/\r|\n/).collect { |s| s != "" && !s.nil? ? s : nil }.compact
        if messages.any?
          last_character = @buffer[-1..-1]
          @buffer = if ["\n", "\r"].include?(last_character)
            ""
          else
            messages.pop.to_s
          end

          messages.each do |message|
            message.strip!
            process_request(*parse_message(message))
          end
        end
        sleep 0.25
      end
    end

    def parse_message(message)
      prefix, message = if message =~ /^\:([^\ ]*) (.*)/
        message.scan(/^\:([^\ ]*) (.*)/)[0]
      else
        [ nil, message ]
      end

      command, parameters = message.split(/\:/, 2)
      [ prefix, command, parameters ].map! { |s| s && s.strip }
    end

    def process_request(prefix, command, parameters)
      origin = if !prefix.nil? && prefix != ""
        Origin.new(prefix)
      end

      (@request_processors + @processors).each do |processor|
        begin
          processor.call(self, origin, command, parameters)
        rescue => e
          puts e.message
        end
      end
    end

    def process_response(origin, command, parameters)
      (@response_processors + @processors).each do |processor|
        begin
          processor.call(self, origin, command, parameters)
        rescue => e
          puts e.message
        end
      end
      @socket.send("#{command} :#{parameters}\r\n", 0)
    end

    def origin
      @origin ||= Origin.new("#{@nickname}!#{@username}@#{@hostname}")
    end

    def add_request_processor(processor = nil, &block)
      @request_processors << (processor || block)
    end

    def add_response_processor(processor = nil, &block)
      @response_processors << (processor || block)
    end

    def add_processor(processor = nil, &block)
      @processors << (processor || block)
    end

    def connect
      @socket = TCPSocket.new(@server[:hostname], @server[:port])
      trap("INT") do
        @socket.close
      end
      trap("KILL") do
        @socket.close
      end
    end

    def authenticate
      send_message "NICK #{@nickname}"
      send_message "USER #{@username} #{@hostname} bla :#{@fullname}"
    end

    def join_room(room, password = nil)
      send_message("JOIN #{room}" + (password ? " #{password}" : ""))
    end

    def say(to, message)
      send_message "PRIVMSG #{to} :#{message}"
    end

    def send_message(message)
      command, parameters = message.strip.split(/\:/, 2)
      process_response(origin, command.to_s.strip, parameters)
    end
  end
end

if File.expand_path($0) == File.expand_path(__FILE__)
  require File.dirname(__FILE__) + '/processor/ping'
  require File.dirname(__FILE__) + '/processor/logger'
  require File.dirname(__FILE__) + '/processor/greeter'
  require File.dirname(__FILE__) + '/origin'

  class AcceptInvitations
    def call(bot, origin, command, parameters)
      if command =~ /^INVITE #{bot.nickname}$/i
        room = parameters.scan(/\#+[a-zA-Z0-9]+$/i)
        if room
          bot.join_room(room)
        end
      end
    end
  end

  bot = Sprinkles::Bot.new(:username => "sparkles", :fullname => "Sparkles", :nickname => "Sparkles")
  bot.add_request_processor do |bot, origin, command, parameters|
    puts "[#{Time.now}] #{origin} > [#{command}] #{parameters}"
  end
  bot.add_processor(Sprinkles::Processor::Logger.new)
  bot.add_request_processor(Sprinkles::Processor::Greeter.new)
  bot.add_request_processor(AcceptInvitations.new)
  bot.start
end