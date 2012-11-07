require 'sequel'

# Connecting to database
# http://sequel.rubyforge.org/rdoc/files/doc/opening_databases_rdoc.html
# ---------------------------------


# gem install pg         # database adapter
# gem install sequel_pg  # making postgres faster (optional)

# DB = Sequel.connect(:adapter  =>'postgres', 
#                     :host     =>'localhost', 
#                     :database =>'tinyclone', 
#                     :user     =>'postgres',  
#                     # :logger => Logger.new('log/db.log'),
#                     :password =>'blablabla')

DB = Sequel.connect(ENV['DATABASE_URL'] ||'postgres://postgres:@localhost/tinyclone')
  
# SQLite in-memory database used during testing                    
# DB = Sequel.sqlite


# Logging SQL Queries
# ---------------------------------

require 'logger'
DB.loggers << Logger.new($stdout)