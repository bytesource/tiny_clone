require_relative 'database/connection'                    
require_relative 'database/associations'

links = DB[:links]

puts Url[1].nil?