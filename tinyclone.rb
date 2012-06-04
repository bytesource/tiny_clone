# Install missing gems

# NOTE: Typo in original code: restclient instead of rest-client
# NOTE: gem install xml-simple, BUT require 'xmlsimple' (no hyphen)
# NOTE: Need to add dm-migrations to the list of required gems, otherwise DataMapper::auto_migrate! cannot be found:
# http://datamapper.lighthouseapp.com/projects/20609/changesets/98f9311d58357c38beb8c779d12be5f0c62fcb72
# NOTE: Instead of requiring all theses dm-xxx gems, you can just require 'data_mapper' that includes everything you need.
%w(rubygems sinatra haml dm-core dm-migrations dm-transactions dm-timestamps dm-types uri rest-client xmlsimple ./dirty_words).each do |lib|
  require lib
end


# ======================
# Application Flow
# ======================

configure do
  # If you want the logs displayed you have to do this before the call to setup
  # http://datamapper.org/getting-started.html
  DataMapper::Logger.new(STDOUT, :debug)
  DataMapper.setup(:default, ENV['DATABASE_URL'] || 'mysql://root:moinmoin@localhost/tinyclone')
end

get '/' do haml :index end

# The 'create shortened' URL route is a HTTP POST request to (/).
# It is used to create the short URL.
# First, it makes sure that the input is a valid HTTP or HTTPS URL.
# If it is, it will use the shorten method in the Link class to create a Link object,
# which is then passed on to the view.
post '/' do
  uri    = URI::parse(params[:original])
  custom = params[:custom].empty? ? nil : params[:custom]
  # URI::parse('http://www.sovonexxxxxxxx.com')
  # => #<URI::HTTP:0x00000001df60a0 URL:http://www.sovonexxxxxxxx.com>
  # The above URL does not exist, but URI::parse still returns an URI::HTTP object.
  # Therefore the following test will probably never detect any non-existing URL.
  raise "Invalid URL" unless uri.kind_of?(URI::HTTP) or uri.kind_of?(URI::HTTPS)

  @link = Link.shorten(params[:original], custom)

  haml :index
end

# The short URL route is the one that is most frequently used.
# Given the short URL, it redirects the user to the original URL.
# At the same time it records the call as a visit.
get '/:short_url' do
  link = Link.first(:identifier => params[:short_url])    # find entry for short_url (but what if it cannot be found???)
  link.visits << Visit.create(:ip => get_remote_ip(env)) # create new Visit object (each Visit object will be one count)
  link.save

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

['/info/:short_url', '/info/:short_url/:num_of_days', '/info/:short_url/:num_of_days/:map'].each do |path|
  get path do
    @link = Link.first(:identifier => params[:short_url])
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

class Url
  include DataMapper::Resource
  property :id,       Serial
  property :original, String, :length => 255

  # Adds an additional column 'link_identifier' as a foreign key
  # (The 'identifier' column is Link's primary key)
  belongs_to :link
end

class Link
  include DataMapper::Resource
  property :identifier, String, :key => true
  property :created_at, DateTime
  has 1, :url
  has n, :visits


  def self.shorten(original, custom=nil)
    # Check if the url is already stored in the database
    url = Url.first(:original => original)
    # If the original URL is already shortended, return the shortened link right away.
    return url.link if url

    link = nil

    if custom  # not 'nil'
      # Check if the custom url is already stored in the database
      raise 'Someone has already take this custom URL, sorry' unless Link.first(:identifier => custom).nil?

      raise 'This custom URL is not allowed due to profanity' if DIRTY_WORDS.include? custom

      # Everything is ok, go ahead and store the custom url.
      transaction do |txn|
        link = Link.new(:identifier => custom)  # new Link instance
        link.url = Url.create(:original => original) # link has one url
        link.save
      end
    else  # custom = 'nil' => call 'create_link' (creates and stores the shortened link)
      transaction do |txn|
        link = create_link(original)
      end
    end

    link
  end

  def self.create_link(original)
    url = Url.create(:original => original)
    # to_s(base=10) → string
    # Returns a string containing the representation of fix radix base (between 2 and 36)
    # 12345.to_s(36)   #=> "9ix
    short_link = url.id.to_i.to_s(36) # http://stackoverflow.com/questions/6727490/how-do-i-handle-the-wrong-number-of-method-arguments
    # We only proceed if the shortened link is not found in the links table and does not contain any dirty words.
    if Link.first(:identifier => short_link.nil?) or !DIRTY_WORDS.include?(short_link)
      link = Link.new(:identifier => short_link)
      link.url = url
      link.save
      return link
    else  # shortend link either already in database or contains dirty words
      # Recurse and try again
      create_link(original)
    end
  end
end

class Visit
  include DataMapper::Resource
  property :id,           Serial
  property :created_at,   DateTime
  property :ip,           IPAddress
  property :country,      String

  # Adds an additional column 'link_identifier' as a foreign key
  # (The 'identifier' column is Link's primary key)
  belongs_to :link

  after :create, :set_country

  def set_country
    xml = RestClient.get "http://api.hostip.info/get_xml.php?ip=#{ip}"  # Where does ip come from???
    self.country = XmlSimple.xml_in(xml.to_s, 'ForceArray' => false)['featureMember']['Hostip']['countryAbbrev']
    self.save
  end

  def self.count_by_date_with(identifier, num_of_days)
    # Returns an array of Ruby Struct objects
    # Selects each distinct date with the number of its occurences (number of rows).
    # Chooses those dates that are associated with the correct identifier (short link) and that
    # were created within the required time frame.
    # visits = repository(:default).adapter.query(<<-QUERY)   # Where does the name 'link_identifier' (see query below) come from???
    # SELECT date(created_at) as date, count(*) as count
    # FROM visits
    #   where link_identifier = '#{identifier}' and
    #         created_at between CURRENT_DATE-#{num_of_days} and
    #         CURRENT_DATE+1
    #   group by date(created_at)
    # QUERY
    visits = repository(:default).adapter.query("SELECT date(created_at) as date, count(*) as count FROM visits where link_identifier = '#{identifier}' and created_at between CURRENT_DATE-#{num_of_days} and CURRENT_DATE+1 group by date(created_at)")

    # SQL does not return empty dates, so we need to
    # manually add the dates where there were no visits:
    dates = (Date.today-num_of_days..Date.today)  # Array of Date objects
    results = {}
    dates.each do |date|
      visits.each do |visit|
        # Assumes that the date objects in 'dates' and 'visits' are in the same order.
        results[date] = visit.count if     visit.date == date
        results[date] = 0           unless results[date]
      end
      results.sort.reverse  # <Date> => count hash
    end
  end

  # Returns an array of Ruby Struct objects (<country>, <count>)
  def self.count_by_country_with(identifier)
    repository(:default).adapter.query(<<-QUERY)
    SELECT country, count(*) as count
    FROM visits
      where link_identifier = '#{identifier}'
      group by country
    QUERY
  end

  # Returns vertical bar chart that shows the visit count by date.
  def self.count_days_bar(identifier, num_of_days)
    visits = count_by_date_with(identifier, num_of_days) # <Date> => count hash
    data, labels = [], []

    visits.each do |date,count|
      data   << count
      labels << "#{date.day}/#{date.month}"
    end

    url_core   = "http://chart.apis.google.com/chart?chs=820x180&cht=bvs&chxt=x&chco=a4b3f4&chm=N,000000,0,-1,11&chxl=0:|"
    url_custom = "#{labels.join('|')}&chds=0,#{data.sort.last+10}&chd=t:#{data.join(',')}"

    url_core + url_custom
  end

  def self.count_days_bar(identifier,num_of_days)
    visits = count_by_date_with(identifier,num_of_days)
    data, labels = [], []
    visits.each {|visit| data << visit[1]; labels << "#{visit[0].day}/#{visit[0].month}" }
    "http://chart.apis.google.com/chart?chs=820x180&cht=bvs&chxt=x&chco=a4b3f4&chm=N,000000,0,-1,11&chxl=0:|#{labels.join('|')}&chds=0,#{data.sort.last+10}&chd=t:#{data.join(',')}"
  end


  # Returns vertical bar chart that shows the visit count by date.
  # map = The geographical zoom-in of the map we want and returns two charts.
  def self.count_country_char(identifier, map)    countries, count = [], []

    # Array of Ruby Struct objects (<country>, <count>)
    count_by_country_with(identifier).each do |visit|
      countries << visit.country
      count     << visit.count
    end

    chart = {}
    url_core_map   = "http://chart.apis.google.com/chart?chs=440x220&cht=t&chtm="
    url_custom_map = "#{map}&chco=FFFFFF,a4b3f4,0000FF&chld=#{countries.join('')}&chd=t:#{count.join(',')}"
    chart[:map] = url_core_map + url_custom_map

    url_core_bar   = "http://chart.apis.google.com/chart?chs=440x220&cht=t&chtm="
    url_custom_bar = "#{map}&chco=FFFFFF,a4b3f4,0000FF&chld=#{countries.join('')}&chd=t:#{count.join(',')}"
    chart[:bar] = url_core_bar + url_custom_bar

    chart
  end


end


# http://stackoverflow.com/a/8517787
DataMapper.finalize

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

# NOTE: Inline templates defined in the source file that requires sinatra are automatically loaded.
# Call enable :inline_templates explicitly if you have inline templates in other source files.


@@ layout
!!! 1.1
%html
  %head
    %title TinyClone
    %link{:rel => 'stylesheet', :href => 'http://www.blueprintcss.org/blueprint/screen.css', :type => 'text/css'}
  %body
    .container
      %p
      = yield

@@ index
%h1.title TinyClone
- unless @link.nil?
  .success
    %code= @link.url.original
    has been shortened to
    %a{:href => "/#{@link.identifier}"}
      = "http://tinyclone.saush.com/#{@link.identifier}"
    %br
    Go to
    %a{:href => "/info/#{@link.identifier}"}
      = "http://tinyclone.saush.com/info/#{@link.identifier}"
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
%h1.title Information
.span-3 Original
.span-21.last= @link.url.original
.span-3 Shortened
.span-21.last
  %a{:href => "/#{@link.identifier}"}
    = "http://tinyclone.saush.com/#{@link.identifier}"
.span-3 Date created
.span-21.last= @link.created_at
.span-3 Number of visits
.span-21.last= "#{@link.visits.size.to_s} visits"

%h2= "Number of visits in the past #{@num_of_days} days"
- %w(7 14 21 30).each do |num_days|
  %a{:href => "/info/#{@link.identifier}/#{num_days}"}
    ="#{num_days} days "
  |
%p
.span-24.last
  %img{:src => @count_days_bar}

