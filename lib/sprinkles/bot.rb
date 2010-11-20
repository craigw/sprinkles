require 'socket'

module Sprinkles
  class Bot
    attr_accessor :nickname, :server

    def initialize(options = {})
      options.each do |option, value|
        instance_variable_set("@#{option}", value)
      end
      @processors = []
      @request_processors = []
      @response_processors = []
      @hostname = Socket.gethostname
      @server ||= { :hostname => options[:hostname] || "localhost", :port => options[:port] || 6667 }
      add_request_processor(Sprinkles::Processor::Ping.new)
      @rooms = options[:rooms] || []
      @password = options[:password] || nil
      @ssl = options[:ssl] || false
      @ssl_verify = options[:ssl_verify] || true
    end

    def start
      connect
      authenticate
      @rooms.each { |room| join_room room }
      loop do
        @buffer ||= ""
        if @ssl
          @buffer += @socket.gets
        else
          @buffer += @socket.recv(1024)
        end
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
          puts e.class.name + ": " + e.message
          puts e.backtrace.join("\n")
        end
      end
    end

    def process_response(origin, command, parameters)
      (@response_processors + @processors).each do |processor|
        begin
          processor.call(self, origin, command, parameters)
        rescue => e
          puts e.class.name + ": " + e.message
          puts e.backtrace.join("\n")
        end
      end
      @socket.print("#{command} :#{parameters}\r\n")
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
      if @ssl
        @ssl_context = OpenSSL::SSL::SSLContext.new()
        unless @ssl_verify
          @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        @socket = OpenSSL::SSL::SSLSocket.new(@socket, @ssl_context)
        @socket.sync_close = true
        @socket.connect
      end
      trap("INT") do
        @socket.close
      end
      trap("KILL") do
        @socket.close
      end
    end

    def authenticate
      unless @token.nil?
        send_message "PASS #{@password}"
      end
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
  require File.dirname(__FILE__) + '/../../contrib/processor/logger'
  require File.dirname(__FILE__) + '/../../contrib/processor/greeter'
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