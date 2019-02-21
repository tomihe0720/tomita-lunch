require 'sinatra'
require 'sinatra/reloader'

get '/' do
  'hello world!!'
end

get '/callback' do
  if params["hub.verify_token"] != 'hogehoge' #hogehogeでなかった場合は、エラーを返す
    return 'Error, wrong validation token'
  end
  params["hub.challenge"]
end
