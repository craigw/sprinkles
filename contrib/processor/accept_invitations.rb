module Sprinkles
  module Processor
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
  end
end