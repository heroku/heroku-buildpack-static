require "sinatra"

get "/*" do
  "api"
end

run Sinatra::Application
