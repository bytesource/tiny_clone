require_relative 'database/connection'
require_relative 'database/associations'

# links = DB[:links]


# http://sequel.rubyforge.org/rdoc/classes/Sequel/Model/ClassMethods.html#method-i-unrestrict_primary_key
Link.unrestrict_primary_key

# Timestamps
# http://sequel.rubyforge.org/rdoc-plugins/classes/Sequel/Plugins/Timestamps.html

# link = Link.new(:short => 22, :created_at => Time.now)

# link.save

p DB[:links].all # 'created at' CANNOT be nil!
# [{:short=>"hello", :created_at=>nil},
#  {:short=>"hello2", :created_at=>2012-06-13 16:18:24 +0800},
#  {:short=>"22", :created_at=>2012-06-13 16:21:48 +0800}]


# Generating short url:
rand(10 ** 12).to_s(36)
# => "e0xnaop"

