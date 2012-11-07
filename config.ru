require './tinyclone'
# Tell Rack to include Sinatra and Tinyclone, 
# then run the Sinatra application.
%w(sinatra tinyclone).each { |lib| require lib}
run Sinatra::Application


# gem install heroku

# (create git repository)

# heroku create smallurl
# => Creating smallurl... done, stack is cedar
#    http://smallurl.herokuapp.com/

# git push heroku master
# => 


