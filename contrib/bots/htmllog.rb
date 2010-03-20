require 'sprinkles'
require 'processor/logger'
require 'hpricot'
require 'ftools'
require 'builder'
require 'digest/sha1'

# ruby -rubygems -I lib -I contrib contrib/bots/htmllog.rb Shiny irc.freenode.net "#chat"

name, hostname, rooms = ARGV.shift, ARGV.shift, ARGV
options = {
  :username => name,
  :fullname => name,
  :nickname => name,
  :hostname => hostname,
  :rooms => rooms
}

class HtmlLogger
  attr_reader :directory, :log_pattern

  def initialize(log_pattern = "%Y%m%d.html", directory = Dir.pwd)
    @log_pattern = log_pattern
    @directory = directory
  end

  def url_linkers
    [
      [ /([\w]+):\/\/([^\s]+)/, '<a href="\1://\2">\1://\2</a>' ],
      [ /\s(www\.[^\s]+)/i, '<a href="http://\1">\1</a>' ],
      [ /\s(ftp\.[^\s]+)/i, '<a href="ftp://\1">\1</a>' ],
      [ /\s(irc\.[^\s]+)/i, '<a href="irc://\1">\1</a>' ],
      [ /\s(irc\.[^\s]+)/i, '<a href="irc://\1">\1</a>' ],
      [ /\s([^\s]+)@([^\s]+)/, '<a href="mailto:\1@\2">\1@\2</a>' ]
    ]
  end

  def call(bot, origin, command, message)
    if command =~ /^PRIVMSG (\#+[a-zA-Z0-9\_\-\.]+)$/
      now = Time.now.utc
      room = command.scan(/^PRIVMSG (\#+[a-zA-Z0-9\_\-\.]+)$/)[0][0]
      logfile(bot.server[:hostname], room, now) do |xml|
        id = message_id(tai64n(now), origin.nickname, room, message)
        xml.div(:id => id, :class => "message") {
          xml.span(now.strftime('%H:%M:%S'), :class => "time")
          xml.span(origin.nickname, :class => "nickname")
          message.gsub! /&/, '&amp;'
          message.gsub! /</, '&lt;'
          message.gsub! />/, '&gt;'
          message.gsub! /'/, '&apos;'
          message.gsub! /"/, '&quot;'
          url_linkers.each do |regex, replace|
            message.gsub! regex, replace
          end
          xml.span(:class => "content") { xml << message }
        }
      end
    end
  end

  def message_id(*seed)
    Digest::SHA1.hexdigest(seed.join('-'))
  end

  def tai64n(time)
    # TAI64 is 34 seconds ahead of UTC due to leap-seconds and initial 10
    # second difference in 1972.
    fuzz = 34
    now = Time.now.utc
    seconds = now.to_i
    nanoseconds = now.to_f - seconds
    "@40000000%08x%08x" % [ seconds + fuzz, nanoseconds ]
  end

  def filename(server, channel, date)
    channel_directory = File.join(directory, server.downcase.gsub(/[^a-z0-9\_\-\.]/, '_'), channel.downcase.gsub(/[^a-z0-9\_\-\.]/, '_'))
    File.makedirs File.join(channel_directory) if !File.directory?(channel_directory)
    File.join(channel_directory, "#{date.strftime(log_pattern)}")
  end

  def html(server, channel, date, &block)
    title = "irc://#{server}/#{channel}"
    buffer = StringIO.new ""
    xml = Builder::XmlMarkup.new :target => buffer, :indent => 2
    xml.instruct!
    xml.declare! :DOCTYPE, "html", :PUBLIC, "-//W3C//DTD XHTML 1.0 Strict//EN", "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
    xml.html(:xmlns => "http://www.w3.org/1999/xhtml") {
      xml.head {
        xml.title title
        xml.style(:type => "text/css") {
          xml << '.nickname { color: #6633cc; }'
          xml << '.time { color: #999999; }'
          xml << '.message:hover { color: black; background-color: #cccc66; }'
        }
      }
      xml.body {
        xml.h1 title
        xml.h2 "Log for #{date.strftime("%Y-%m-%d")}"
        xml.p "All times are in #{date.strftime('%Z')}."
        xml.div(:id => "messages") {
          messages = current_messages(server, channel, date)
          puts "Archived messages:\n#{messages}" if $DEBUG
          xml << "      #{messages}\n" if messages
          yield xml
        }
      }
    }
    buffer.rewind
    buffer.read
  end

  def current_messages(server, channel, date)
    file = filename(server, channel, date)
    puts "Getting archived messages from #{file}" if $DEBUG
    return if !File.exists?(file)
    f = File.open(file, 'r')
    messages = (Hpricot(f.read) / '#messages .message')
    f.close
    puts "Found #{messages.to_a.size} archived messages" if $DEBUG
    messages.to_html
  end

  def logfile(server, channel, date, &block)
    file = filename(server, channel, date)
    tmpfile = "#{file}-#{date.to_f}.tmp"
    File.open(tmpfile, "w+") { |f|
      f.puts(html(server, channel, date, &block))
    }
    File.move tmpfile, file
  end
end

bot = Sprinkles::Bot.new(options)
bot.add_processor(HtmlLogger.new)
bot.start