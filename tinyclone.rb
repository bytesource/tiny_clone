# http://sinatra-book.gittr.com/#hello_world_application
require 'bundler/setup'

# Install missing gems

# NOTE: Typo in original code: restclient instead of rest-client
# NOTE: gem install xml-simple, BUT require 'xmlsimple' (no hyphen)
# NOTE: Need to add dm-migrations to the list of required gems, otherwise DataMapper::auto_migrate! cannot be found:
# http://datamapper.lighthouseapp.com/projects/20609/changesets/98f9311d58357c38beb8c779d12be5f0c62fcb72
# NOTE: Instead of requiring all theses dm-xxx gems, you can just require 'data_mapper' that includes everything you need.
%w(rubygems sinatra haml uri rest-client xmlsimple ./dirty_words ./database/associations).each do |lib|
  require lib
end

# Hot Reloading ----------------

# http://www.sinatrarb.com/contrib/reloader
# gem install sinatra-contrib
# require "sinatra/reloader" if development?
# => no such file to load -- sinatra/reloader

# Better: Use Shotgun:
# gem install shotgun
# shotgun -p 4567 tinyclone.rb
# source: http://ruby.about.com/od/sinatra/a/sinatra5.htm

# ======================
# Application Flow
# ======================


configure do
  # If you want the logs displayed you have to do this before the call to setup
  # http://datamapper.org/getting-started.html
end


get '/' do haml :index end


# "Create Shortened URL" Route =================================
# The 'create shortened' URL route is a HTTP POST request to (/).
# It is used to create the short URL.
# First, it makes sure that the input is a valid HTTP or HTTPS URL.
# If it is, it will use the shorten method in the Link class to create a Link object,
# which is then passed on to the view.
post '/' do
  uri    = URI::parse(params[:original])
  custom = params[:custom].empty? ? nil : params[:custom] # TODO: Try pinging the site
  # URI::parse('http://www.sovonexxxxxxxx.com')
  # => #<URI::HTTP:0x00000001df60a0 URL:http://www.sovonexxxxxxxx.com>
  # The above URL does not exist, but URI::parse still returns an URI::HTTP object.
  # Therefore the following test will probably never detect any non-existing URL.
  raise "Invalid URL" unless uri.kind_of?(URI::HTTP) or uri.kind_of?(URI::HTTPS)

  link = Link.shorten(params[:original], custom)

  # http://stackoverflow.com/questions/9504094/sinatra-haml-how-to-pass-an-argument-when-calling-a-view-file
  haml :index, :locals => {:link => link}
end


# "Short URL" Route ===============================================
# The short URL route is the one that is most frequently used.
# Given the short URL, it redirects the user to the original URL.
# At the same time it records the call as a visit.
get '/:short_url' do
  # TODO: Do not allow http://example.com and http://www.example.com be treated as different addresses
  short_url = params[:short_url]
  return if short_url =~ /favicon/
  link      = Link.filter(:short => short_url).first
  raise "Invalid short URL '#{short_url}'"  unless link
  ip = get_remote_ip(env)
  
  # Create new Visit object (each Visit object will be one count)
  visit = Visit.create(:ip => ip, :created_at => Time.now) # calls 'after_create' to set :country
  link.add_visit(visit) 

  # The redirect command in Sinatra normally issues a HTTP 302 response code.
  redirect link.url.original, 301
end

# Sinatra gets both the REMOTE_ADDR HTTP environment variable and X-Forwarded-For
# HTTP header through its env variable in the Request object provided by Rack.
# However, the current implementation of Rack (1.0.0) has the ip method in the Request class
# taking the LAST IP address while what we need is really the FIRST IP address.
# Therefore we need to modify the implementation slightly in order to get the IP address.
def get_remote_ip(env)
# X-Forwarded-For provides a list of IP addresses, from the calling client to the last proxy:
# X-Forwarded-For: client1, proxy1, proxy2
  if addr = env['HTTP_X_FORWARDED_FOR']
    addr.split(',').first.strip
  else
    env['REMOTE_ADDR'] # Only gives the IP address of the last proxy.
  end
end

['/info/:short_url', 
 '/info/:short_url/:num_of_days', 
 '/info/:short_url/:num_of_days/:map'].each do |path|
  get path do
    @link = Link.filter(:short => params[:short_url]).first
    raise 'This link has not yet been defined' unless @link

    @num_of_days    = (params[:num_of_days] || 15).to_i
    @count_days_bar = Visit.count_days_bar(params[:short_url], @num_of_days)
    chart           = Visit.count_country_chart(params[:short_url], params[:map] || 'world')
    @count_country_map = chart[:map]
    @count_country_bar = chart[:bar]

    haml :info
  end
end



# ======================
# Data Model
# ======================

class Url < Sequel::Model
  # Nothing to do here...
end

class Link < Sequel::Model


  def self.shorten(original, custom=nil)
    # Check if the url is already stored in the database
    url = Url.filter(:original => original).first
    # If the original URL is already shortened, return the shortened link right away.
    return url.link if url

    link = nil

    if custom  # not 'nil'
      # Check if the custom url is already stored in the database
      flash[:error] = 'Someone has already take this custom URL, sorry' unless Link.filter(:short => custom).first.nil?

      raise 'This custom URL is not allowed due to profanity' if DIRTY_WORDS.include? custom

      # Everything is OK, go ahead and store the custom URL.
      DB.transaction do
        link = Link.create(:short => custom, :created_at => Time.now) # new Link instance
        link.url = Url.new(:original => original) # With link.url, Url.new will automatically saved to db.
      end
    else  # custom = 'nil' => call 'create_link' (creates and stores the shortened link)
      DB.transaction do
        link = create_link(original)
      end
    end

    link
  end

  def self.create_link(original)
    # #create == store in DB (so that we get an id).
    # This also means that if we need to recurse, this URL row entry's foreign key will be empty.
    # => abandoned row entry.
    # => On the next call to #create_link we will get a new id. 
    url = Url.create(:original => original) 
    # to_s(base=10) → string
    # Returns a string containing the representation of fix radix base (between 2 and 36)
    # 12345.to_s(36)   #=> "9ix
    short_link = url.id.to_s(36) # http://stackoverflow.com/questions/6727490/how-do-i-handle-the-wrong-number-of-method-arguments
    # We only proceed if the shortened link is not found in the links table and does not contain any dirty words.
    if Link.filter(:short => short_link).first.nil? && !DIRTY_WORDS.include?(short_link) # before: 'or'
      link     = Link.create(:short => short_link, :created_at => Time.now)
      link.url = url
      return link
    else  # shortened link either already in database or contains dirty words
      create_link(original) # Recurse and try again
    end
  end
end

class Visit < Sequel::Model
  # http://sequel.rubyforge.org/rdoc/files/doc/model_hooks_rdoc.html
  def after_create
    set_country
    super
  end

  def set_country
    xml = RestClient.get "http://api.hostip.info/get_xml.php?ip=#{ip}"  # We get 'ip' from #get_remote_id
    country = XmlSimple.xml_in(xml.to_s, 'ForceArray' => false)['featureMember']['Hostip']['countryAbbrev']
    self.country = country 
  end

  def self.count_by_date_with(short, num_of_days)
    # Selects each distinct date with the number of its occurrences (number of rows).
    # Chooses those dates that are associated with the correct short (short link) and that
    # were created within the required time frame.

    # POSTGRESQL:
    # visits = DB.fetch(<<-QUERY) 
    # SELECT date(created_at) as date, count(*) as count
    # FROM visits
    #   where link_short = '#{short}' and
    #         created_at between CURRENT_DATE-#{num_of_days} and
    #         CURRENT_DATE+1
    #   group by date(created_at)
    # QUERY
    
    # Alternative:
    visits = Visit.group_and_count{ date(created_at) }.
                   filter(:link_short => short).
                   filter(:created_at => (Date.today - num_of_days) .. (Date.today + 1)).all
    # [{:date=>#<Date: 2012-10-31 (4912463/2,0,2299161)>, :count=>2}]
    # TODO: Transfer into a set of dates and check dates against set to avoid nested loop below
 
    # SQL does not return empty dates, so we need to
    # manually add the dates where there were no visits:
    dates = (Date.today-num_of_days..Date.today)  # Array of Date objects
    results = {}
    dates.each do |date|
      visits.each do |visit| # {:date=>#<Date: 2012-11-03 (4912469/2,0,2299161)>, :count=>1}:Hash
        # Assumes that the date objects in 'dates' and 'visits' are in the same order.
        results[date] = visit[:count] if     visit[:date] == date 
        results[date] = 0             unless results[date]
      end
    end
    results.sort.reverse  # <Date> => count hash
  end
    


  # Returns an array of Visit objects
  # # [#<Visit @values={:country=>"China", :count=>1}>, #<Visit @values={:country=>"Germany", :count=>1}>]
  def self.count_by_country_with(short)
  Visit.group_and_count(:country).filter(:link_short => short).all
  # SELECT \"country\", count(*) AS \"count\" 
  # FROM \"visits\" 
  #   WHERE (\"link_short\" = 'I am evil') 
  #   GROUP BY \"country\"
  end

  # Returns vertical bar chart that shows the visit count by date.
  def self.count_days_bar(short, num_of_days)
    visits = count_by_date_with(short, num_of_days) # <Date> => count hash
    data, labels = [], []

    visits.each do |date, count|
      data   << count 
      labels << "#{date.day}/#{date.month}"
    end
    
    data = data.empty? ? [0] : data # Prevents error on #{data.sort.last+10} if data is empty.
    
    
    # FIXME: Avoid nil error on + if array is empty (= where link_short = '#{short}' returns no results)

    url_core   = "http://chart.apis.google.com/chart?chs=820x180&cht=bvs&chxt=x&chco=a4b3f4&chm=N,000000,0,-1,11&chxl=0:|"
    url_custom = "#{labels.join('|')}&chds=0,#{data.sort.last+10}&chd=t:#{data.join(',')}"

    url_core + url_custom
  end


  # Returns vertical bar chart that shows the visit count by date.
  # map = The geographical zoom-in of the map we want and returns two charts.
  def self.count_country_chart(short, map)    
    countries, counts = [], []
    
    cbcw = count_by_country_with(short) # [#<Visit @values={:country=>"XX", :count=>1}>]

    cbcw.each do |visit|
      countries << visit[:country]
      counts     << visit[:count]
    end
    

    chart = {}
    url_core_map   = "http://chart.apis.google.com/chart?chs=440x220&cht=t&chtm="
    url_custom_map = "#{map}&chco=FFFFFF,a4b3f4,0000FF&chld=#{countries.join('')}&chd=t:#{counts.join(',')}"
    chart[:map]    = url_core_map + url_custom_map

    url_core_bar   = "http://chart.apis.google.com/chart?chs=440x220&cht=t&chtm="
    url_custom_bar = "#{map}&chco=FFFFFF,a4b3f4,0000FF&chld=#{countries.join('')}&chd=t:#{counts.join(',')}"
    chart[:bar]    = url_core_bar + url_custom_bar

    chart # {:map => http..., :bar => http...}
  end


end


# http://stackoverflow.com/a/8517787
# DataMapper.finalize

# enable :inline_templates

__END__

# ======================
# View
# ======================

# Ruby has a __END__ directive that indicates that anything that comes after it will not be parsed.
# Instead, we can use the DATA constant to get the rest of the data after the __END__ directive.
#
# Using the command use_in_file_templates! we can tell Sinatra
# to use whatever comes after the __END__ directive as the template files.
# As a result, the Haml templates at the end of the file are the templates for the Sinatra application.

# NOTE: Changelog for Sinatra 1.0
# The `use_in_file_templates` method is obsolete.
# Use `enable :inline_templates` or `set :inline_templates, 'path/to/file'`
# https://github.com/sinatra/sinatra/blob/master/CHANGES

# NOTE: Inline templates defined in the source file that require sinatra are automatically loaded.
# Call enable :inline_templates explicitly if you have inline templates in other source files.


@@ layout
!!! 1.1
%html
  %head
    %title TinyClone
    %link{:rel => 'stylesheet', :href => 'http://www.blueprintcss.org/blueprint/screen.css', :type => 'text/css'}
    %link{:rel => 'shortcut icon', :href => '/x-favicon.png', :type => 'image/x-icon'}
  %body
    .container
      %p
      = yield

@@ index
%h1.title TinyClone
- unless locals[:link].nil?
  .success
    %code= link.url.original
    has been shortened to
    %a{:href => "/#{locals[:link].short}"}
      = "http://tinyclone.saush.com/#{locals[:link].short}"
    %br
    Go to
    %a{:href => "/info/#{locals[:link].short}"}
      = "/tinyclone.saush.com/info/#{locals[:link].short}"
    to get more information about this link.
- if env['sinatra.error']
  .error= env['sinatra.error']
%form{:method => 'post', :action => '/'}
  Shorten this:
  %input{:type => 'text', :name => 'original', :size => '70'}
  %input{:type => 'submit', :value => 'now!'}
  %br
  to http://tinyclone.saush.com/
  %input{:type => 'text', :name => 'custom', :size => '20'}
  (optional)
%p
%small copyright &copy;
%a{:href => 'http://blog.saush.com'}
  Chang Sau Sheong
%p
  %a{:href => 'http://github.com/sausheong/tinyclone'}
    Full source code

@@info
- if env['sinatra.error']
  .error= env['sinatra.error']
%h1.title Information
- unless @link.nil?
  .span-3 Original
  .span-21.last= @link.url.original
  .span-3 Shortened
  .span-21.last
    %a{:href => "/#{@link.short}"}
      = "http://tinyclone.saush.com/#{@link.short}"
  .span-3 Date created
  .span-21.last= @link.created_at
  .span-3 Number of visits
  .span-21.last= "#{@link.visits.size.to_s} visits"
  
  %h2= "Number of visits in the past #{@num_of_days} days"
  - %w(7 14 21 30).each do |num_days|
    %a{:href => "/info/#{@link.short}/#{num_days}"}
      ="#{num_days} days "
    |
  %p
  .span-24.last
    %img{:src => @count_days_bar}
    %img{:src => @count_country_bar}


