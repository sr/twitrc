require 'rubygems'
require 'eventmachine'
require 'twitter'
require 'activesupport'
require 'lib/irc_numconst'

$debug = true
$servername = "twitter.irc"

module TwitRC
@username = ""
@password = ""
@nickname = ""

  def send_data(data)
    super
    puts "<< %s" % data if $debug
  end
  
  def receive_data(data)
    data.match(/\n/) ? data.split(/\r?\n/).each{|x|process_data(x)}:process_data(data.strip)
  end
  
  def process_data(data)
    puts ">> %s" % data if $debug
    # we assume that if there is no leading colon here, we're dealing with a command and call a method
    if data =~ /^:{0}/ then
      self.send("irc_%s"%data.match(/^(.*?) (.*)$/)[1].downcase,$2)
    end
  end
  
  def irc_pass(password)
    @password = password
  end
  
  def irc_nick(nickname)
    @nickname = nickname
  end
  
  def irc_user(username)
    @username = username.match(/^(.*?) /)[1]
    do_twitter_connection()
  end
  
  def irc_privmsg(message)
    @twit.update(message.gsub(/^.*?:/,""))
  end

  def irc_quit(message)
    close_connection
  end
  
  def method_missing(id, *args)
    puts "*** this feature is currently unsupported (#{id})"
    pp args 
  end
  
  def privmsg(sender, message, channel=nil)
    send_data ":#{sender} PRIVMSG #{channel} :#{message}\n"
  end
  
  def do_twitter_connection()
    @twit = Twitter::Base.new(@nickname, @password)
     rpl RPL_MOTDSTART, ":- #{$servername} message of the day"
     rpl RPL_MOTD, ":- Thank you for using TwitRC"
     rpl RPL_ENDOFMOTD, ":End of /MOTD command"
     send_data ":#{@nickname}!#{$servername} JOIN :#twitter\n"
     send_data ":#{$servername} MODE #twitter +ns\n"
     names = ""
     @cache = @twit.friends
     @cache.each do |u| 
       names << " #{u.screen_name}"
     end
     rpl RPL_NAMREPLY, ":@twitter @#{@nickname}#{names}", "@ #twitter"
     rpl RPL_ENDOFNAMES, ":End of /NAMES list.", "#twitter"
      @cache.each do |u|
        privmsg(u.screen_name,CGI::unescapeHTML(u.status.text),"#twitter")
      end
  end

  def rpl(num, message, channel=nil)
    send_data ":#{$servername} #{num} #{@nickname} #{channel} #{message}\n"
  end
  
  def initialize()
    time = Time.now
    EventMachine::add_periodic_timer(5.minutes) do
      @twit.timeline(:friends, :since => Time.now.in_time_zone("Eastern Time (US & Canada)") - 5.minutes).each do |u|
        privmsg(u.user.screen_name,CGI::unescapeHTML(u.text), "#twitter")
      end
      send_data "ping :#{$servername}\n"
    end
  end
  
end

EventMachine::run {
  EventMachine::start_server "127.0.0.1", 10000, TwitRC
}