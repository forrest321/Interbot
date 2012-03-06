require 'cinch'
require 'net/http'
require 'barometer'
require 'open-uri'
require 'rubygems'
require 'hpricot'
require 'whois'
require 'twilio-ruby'
require 'nokogiri'
require 'cgi'
require 'gmail' #ix2bot@gmail.com/interbot11
require 'htmlentities'
require 'crack'

bot = Cinch::Bot.new do
  @bot = self;

  configure do |c|
    c.server = 'irc.freenode.org'
    c.channels = ['#ix2-bot','#ix2-2','#ix2-github']
    c.nick = 'interbot'
  end

  helpers do
    def urban_dict(query)
	  url = "http://www.urbandictionary.com/define.php?term=#{CGI.escape(query)}"
	  puts url
	  CGI.unescape_html Nokogiri::HTML(open(url)).at("div.definition").text.gsub(/\s+/, ' ') rescue nil
	end
	
	def doorman
  	  employee_ids = {:frankh => 9999, :davecow => 1223, :CodyC => 3994, :robbihun => 3938, :Ash_Work => 3974, :keithtronic => 3904, :isau => 3917, :clark => 3965, :dgarv => 4051}
      emp_in, emp_out = [], []
      employee_ids.keys.each do |employee|
        url = "http://doorman/reports/employeeReport.aspx?employeeID=#{employee_ids[employee]}"
        puts "#{employee}: #{url}"
        doc = open(url) {|f| Hpricot(f)}
	    element = doc.search("#page_content > table").last.search("tr").last.search("td")[1]
        status = element.nil? ? "" : element.inner_html
        if status.match(/In the Office/)
          emp_in << employee
        else
          emp_out << employee
        end
      end
      return {:in => emp_in, :out => emp_out}
	end
  end
  
  on :message, "hello" do |m|
    nick = m.user.nick
    match = nick.match(/^fo+\d?$/)
	m.reply match.nil? || match[0] != nick ? "Hello, #{nick}" : "GTFO, #{nick}"
  end
  
  on :message, /^#{self.nick} push (.*) to (.*)$/ do |m, project_name, destination|
    project_name = "#{project_name} #{destination}"
    m.reply "Pushing #{matches[0]} to #{matches[1]} by building #{project_name} on Hudson"
    url = URI.parse("http://jaws:8080/job/#{project_name.gsub(' ', '%20')}/build?delay=0sec")
    request = Net::HTTP::Get.new(url.path)
    Net::HTTP.start(url.host, url.port) {|http| http.request(request)}
  end

  on :message, /^#{self.nick} build (.*)$/ do |m, project_name|
    m.reply "Building #{project_name}"
    url = URI.parse("http://jaws:8080/job/#{project_name.gsub(' ', '%20')}/build?delay=0sec")
    request = Net::HTTP::Get.new(url.path)
    Net::HTTP.start(url.host, url.port) {|http| http.request(request)}
  end

  on :message, /^#{self.nick} pick lunch$/ do |m|
    lunches = ["Sitar", "Jason's Deli", "Dreamland", "Sweet Tea", "Rogue", "Acapulco", "Rojo", "Niki's West", "Moe's BBQ", "Mexico Lindo", "Jimmy John's", "Homewood Diner", "Sarris"]
    if [2,4].include?(Time.now.wday)
      20.times do
        lunches << "Sitar"
      end
    end
    m.reply "What about #{lunches.sort_by{rand}[0]}?"
  end

  on :message, /[Ww]hat'?s for lunch/ do |m|
	public_key = '302fde7b5e4f7fd48bb0b52b7957e11d'
	board_id = '4f202ad1110d3111281f2f63'
	api_lists = "https://api.trello.com/1/boards/#{board_id}/lists/open?key=#{public_key}"
	suggestion_count = 3
	list_today = Crack::JSON.parse(open(api_lists).read)[Date.today.wday]
	api_cards = list_today['cards']
	lunch_options = []
	api_cards.each do |card|
		api_card_url = "https://api.trello.com/1/cards/#{card["id"]}?fields=name,idList&member_fields=fullName&key=#{public_key}"
		api_card = Crack::JSON.parse(open(api_card_url).read)
		lunch_options << { :name => api_card["name"], :votes => api_card["badges"]["votes"] } if api_card["labels"].any? {|label| label["name"] == 'This Week' }
	end
	lunch_options = lunch_options.sort_by {|opt| opt[:votes]}.reverse
	while suggestion_count > 0 && lunch_options.length > 0
		opt = lunch_options.pop
		m.reply "#{opt[:name]} has #{opt[:votes]} votes"
		suggestion_count = suggestion_count - 1
	end
  end
  
  on :message, /^#{self.nick} weather($| .*$)/ do |m, location|
    location = "Birmingham, AL" if location ==''
    barometer = Barometer.new(location)
    weather = barometer.measure
    m.reply "Currently #{weather.current.temperature} and #{weather.current.icon}"
  end
  
  on :message, /^#{self.nick} forecast($| .*$)/ do |m, location|
    location = "Birmingham, AL" if location == ''
    barometer = Barometer.new(location)
    weather = barometer.measure
    m.reply "Today: #{weather.forecast[0].icon}. High of #{weather.forecast[0].high}, low of #{weather.forecast[0].low}. Sunset at #{weather.forecast[0].sun.set}"
    m.reply "Tomorrow: #{weather.forecast[1].icon}. High of #{weather.forecast[1].high}, low of #{weather.forecast[1].low}. Sunset at #{weather.forecast[1].sun.set}"
  end

  on :message, /^#{self.nick} doorman$/ do |m|
    emps = doorman
    m.reply "In: #{emps[:in].join(', ')}"
    m.reply "Out: #{emps[:out].join(', ')}"
  end

  on :message, /^#{self.nick} whois (.*)$/ do |m, domain|
    r = Whois.whois(domain)
	m.reply "#{domain} is available" if r.available?
	if (r.registered?)
	  m.reply "#{domain} was registered on #{r.created_on.strftime("%m/%d/%Y")} by #{r.admin_contact.name} (#{r.admin_contact.organization}) through #{r.registrar.name}"
	end
  end
  
  on :message, /^#{self.nick} batsignal($| .*$)/ do |m, destination|
    match = m.user.nick.match(/^fo+\d?$/)
	return unless match.nil? || match[0] != m.user.nick

	weather = Barometer.new("Birmingham, AL").measure
	location = weather.wet? ? 'by the door (chance of rain)' : 'outside'
	emps = doorman
	destination = "for #{destination}" unless destination == ''
	employees = {
				  #:dgarv => '',
	              #:frankh => '2056125241@txt.att.net',
	              :davecow => '2056170775@txt.att.net',
	              :CodyC => '2059601539@txt.att.net',
	              :Ash_Work => '2056173946@txt.att.net',
	              :keithtronic => '3346692522@messaging.sprintpcs.com',
	              :clark => '3342216642@vtext.com'
				}
	gmail = Gmail.connect('ix2bot@gmail.com', 'interbot11')
    emps[:in].each do |e|
      unless employees[e].nil?
        gmail.deliver do
  	      to employees[e]
    	  body "Lunch train is leaving #{destination} - meet #{location}"
    	end
      end
    end
    gmail.logout
	m.reply "Messages sent"
  end
  
  on :message, /^#{self.nick} roll (\d*)d(\d+)($|[\+\-]\d+$)/ do |m, n, d, mod|
    total = 0;
	dice = n.to_i == 0 ? 1 : [n.to_i.abs, 10].min
	
    dice.times do
	  result = (Random.new).rand(1..d.to_i.abs)
      m.reply "#{m.user.nick} rolls a #{result}"
	  total += result
	end
	unless mod.to_i == 0
	  m.reply "Adding #{mod}"
	  total += mod.to_i
	end
	m.reply "Total: #{total}" if dice > 1 || mod.to_i != 0
  end
  
  on :message, /^#{self.nick} urban (.*)/ do |m, term|
    match = m.user.nick.match(/^fo+\d?$/)
	return unless match.nil? || match[0] != m.user.nick
    m.reply(urban_dict(term) || "No results found")
  end

  on :message, /^#{self.nick} xkcd/ do |m|
	url = URI.parse('http://dynamic.xkcd.com/random/comic/')
	request = Net::HTTP::Get.new(url.path)
	response = Net::HTTP.start(url.host, url.port) {|http| http.request(request)}
	m.reply response.header['location']
  end
  
  on :message, /haters .*hate/ do |m|
    haters = [
				"http://www.hatersgoingtohate.com/wp-content/uploads/2010/06/haters-gonna-hate-rubberband-ball.jpg", 
				"http://www.hatersgoingtohate.com/wp-content/uploads/2010/06/haters-gonna-hate-cat.jpg", 
				"http://jesad.com/img/life/haters-gonna-hate/haters-gonna-hate01.jpg", 
				"http://i671.photobucket.com/albums/vv78/Sinsei55/HatersGonnaHatePanda.jpg", 
				"http://24.media.tumblr.com/tumblr_lltwmdVpoL1qekprfo1_500.gif",
				"http://www.hatersgoingtohate.com/wp-content/uploads/2011/08/haters-gonna-hate-dog-walker.jpg",
				"http://www.hatersgoingtohate.com/wp-content/uploads/2011/06/haters-gonna-hate-chick.jpg",
				"http://www.hatersgoingtohate.com/wp-content/uploads/2011/04/elf-dog.jpg",
				"http://www.hatersgoingtohate.com/wp-content/uploads/2011/03/haters-gonna-hate-look-at-this-dog.jpg",
				"http://www.hatersgoingtohate.com/wp-content/uploads/2011/02/haters-gonna-hate-wwf.gif",
				"http://www.hatersgoingtohate.com/wp-content/uploads/2011/01/haters_gonna_hate_mario_walking.gif",
				"http://www.hatersgoingtohate.com/wp-content/uploads/2010/06/haters-gonna-hate-oldschool.jpg",
				"http://www.hatersgoingtohate.com/wp-content/uploads/2010/06/haters-gonna-hate-eagle.jpg"
			]
	m.reply haters.sort_by{rand}[0]
  end
  
  on :message, /^([sS]hould|[wW]ill|[iI]s|[dD]id|[hH]as|[dD]oes|[aA]re|[dD]o) .+\?$/ do |m|
	return if (m.include? ' or ')
	responses = [
					"Signs point to yes",
					"Yes",
					"Reply hazy, try again",
					"Without a doubt",
					"My sources say no",
					"As I see it, yes",
					"You may rely on it",
					"Concentrate and ask again",
					"Outlook not so good",
					"It is decidedly so",
					"Better not tell you now",
					"Very doubtful",
					"Yes - definitely",
					"It is certain",
					"Cannot predict now",
					"Most likely",
					"Ask again later",
					"My reply is no",
					"Outlook good",
					"Don't count on it"
				]
	m.reply responses.sort_by{rand}[0]
  end
  
  on :message, /^[Aa]chievement [U|u]nlocked: (.*)/ do |m, achievement|
	url = "http://achievement-unlocked.heroku.com/xbox/#{URI.escape(achievement)}.png"
	m.reply url
  end
  
  on :message, /^[Aa]cheivement [U|u]nlocked:/ do |m|
	title = "L2Spell, #{m.user.nick}"
	url = "http://achievement-unlocked.heroku.com/xbox/#{URI.escape(title)}.png"
	m.reply url
  end
  
  on :message, /\bbees\b/ do |m|
	m.reply "OH, NO! NOT THE BEES! NOT THE BEES! AAAAAHHHHH!"
  end
  
  on :message, "artfarticus, please" do |m|
	doc = Hpricot(open("http://www.asciiartfarts.com/random.cgi")).search('pre').last
	m.reply doc
  end
  
  on :message, /http:\/\/movies.netflix.com\/WiMovie\/(.*)\/(\d+)/ do |m, title, id|
	title = title.gsub(/_/, ' ')
	url = "http://instantwatcher.com/titles?q=#{URI.escape(title)}"
	doc = Hpricot(open(url))
	movie = doc.search("#title-listing > li > a").first.attributes["href"]
	m.reply "#{title}: http://instantwatcher.com#{movie}"
  end
  
  on :message, /(https?:\/\/twitter.com\/#!\/.*\/statu(s|ses)\/\d+)/ do |m, tweet|
	return if tweet.include? '/photo/'
	doc = Hpricot(open(tweet.gsub("#!/",'')))
	user = HTMLEntities.new.decode(doc.search('.screen-name').first.html)
	timestamp = HTMLEntities.new.decode(doc.search('.timestamp').first.html)
	body = doc.search('.entry-content').first
	links = body.search("a.twitter-timeline-link")
	bodytext = body.innerText
	links.each do |link|
		search_link = link.innerText.gsub(/\?/, "\\?").gsub(/\//, "\\/")
		bodytext.gsub!(/#{search_link}/, "http://#{link.innerText}")
	end
	m.reply "@#{user}: #{bodytext} (at #{timestamp})"
  end
  
  on :message, /cooler than being cool/ do |m|
	m.reply "ICE COLD."
  end
  
  on :message, /(.*)/ do |m, text|
	url = "http://127.0.0.1:1337/?text=#{URI.escape(text)}"
	replies = ["That's what she said!", "Your mom said that.", "Your mom said that last night.", "That's what Winger's sister said!"]
	result = open(url).read
	m.reply replies.sort_by{rand}[0] if result == 'true'
  end
  
  on :message, /when'?s lunch/ do |m|
	m.reply "NOW"
  end
  
end

bot.start
