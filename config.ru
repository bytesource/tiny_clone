# Tell Rack to include Sinatra and Tinyclone, 
# then run the Sinatra application.
%w(sinatra ./tinyclone).each { |lib| require lib}
run Sinatra::Application

