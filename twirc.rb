require 'rubygems'
require 'eventmachine'
require 'twitter'
require 'cgi'
require 'activesupport'

module Ircd
  @username = ""
  @pass = ""
  @nickname = ""
  
  def send_data(data)
    super  
    puts ">> #{data}"
  end
  
  def receive_data(data)
    if data.match(/\n{1}/)
      data.split(/\r?\n/).each do |x| process_data(x) end
    else
      process_data(data.strip)
    end
  end
  
  def process_data(data)
    data.strip
    puts "<< #{data}"
    case data
      when /^PRIVMSG (.*?) :(.*)$/
        @twit.update($2)
      when /^USER (.*?) /m
        @username = $1
        puts "#{@username} - #{@pass} - #{@nickname}"
        @twit = Twitter::Base.new(@username, @pass)
        connect_user()
      when /^PASS (.*)/
        @pass = $1
      when /^NICK (.*)/
        @nickname = $1
      when /^WHO \#twitter/
        @twit.friends.each do |u|
          send_data(":localhost 352 #{u.screen_name} #twitter #{u.screen_name} twitter localhost #{u.screen_name} H :0 #{u.name}")
        end
        servermsg("End of /WHO list.", 315, "#twitter")
      when /^NAMES \#twitter/
        names = String.new
        @twit.friends.each do |u| 
          names << "#{u.screen_name} "
        end
        servermsg("@twitter #{names}", 353, "#twitter")
        servermsg("End of /NAMES list.", 366, "#twitter")
    end
  end
  
  def connect_user()
    servermsg("*** Connecting to twitter", "NOTICE AUTH")
    send_data ":#{@nickname}!localhost JOIN :#twitter\n"
    send_data ":localhost MODE #twitter +ns\n"
    names = String.new
    @twit.friends.each do |u| 
      names << "#{u.screen_name} "
    end
    servermsg("@twitter #{names}", 353, "#twitter")
    servermsg("End of /NAMES list.", 366, "#twitter")
    @twit.friends.each do |u|
      privmsg(u.screen_name,CGI::unescapeHTML(u.status.text),"#twitter")
    end
  end
  
  def privmsg(sender, message, channel=nil)
    send_data ":#{sender} PRIVMSG #{channel} :#{message}\n"
  end
  
  def servermsg(message, id=nil, channel=nil)
    send_data ":localhost #{id} #{@nickname} #{channel} :#{message}\n"
  end
  
  def post_init()
    puts "== new connection =="
  end
  
  def initialize()
    time = Time.now
    EventMachine::add_periodic_timer(5.minutes) do
    @twit.timeline(:friends, :since => Time.now.in_time_zone("Eastern Time (US & Canada)") - 5.minutes).each do |u|
      privmsg(u.user.screen_name,CGI::unescapeHTML(u.text), "#twitter")
    end
    
    send_data "PING :localhost\n"
    end
  end

end

EM.run {
  EM.start_server "0.0.0.0", 10000, Ircd
}