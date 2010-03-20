require 'sprinkles'
require 'processor/logger'

# ruby -I lib -I contrib contrib/bots/simplelog.rb Shiny irc.freenode.net "#chat"

name, hostname, rooms = ARGV.shift, ARGV.shift, ARGV
options = {
  :username => name,
  :fullname => name,
  :nickname => name,
  :hostname => hostname,
  :rooms => rooms
}

bot = Sprinkles::Bot.new(options)
bot.add_processor(Sprinkles::Processor::Logger.new)
bot.start