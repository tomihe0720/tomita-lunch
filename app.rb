require 'sinatra'
require 'sinatra/reloader'
require 'json'
require 'rest_client'

FB_ENDPOINT = "https://graph.facebook.com/v2.6/me/messages?access_token=" + "EAAEIr8ppJUYBALtJmTQ7zk6zoQbKXHBoHqL3iOalZCcC1WtjzIqOvHYcasMZAuZBvKSjxt59y3MiDQVNjUcTP0kP85lzZCGg4rLW9MCOvwjb6QnL469vmnwbexVeFFStRauUqovl94ZA3XtxlavW97Xp5iAhYCFn0W9r0ZAeQcmgZDZD"

get '/' do
  'hello world!!'
end

get '/callback' do
  if params["hub.verify_token"] != 'hogehoge' #hogehogeでなかった場合は、エラーを返す
    return 'Error, wrong validation token'
  end
  params["hub.challenge"]
end

post '/callback' do
  hash = JSON.parse(request.body.read)
  message = hash["entry"][0]["messaging"][0] #entryの0個目のmessagingの0個目
  sender = message["sender"]["id"] #上記で取得したmessage変数の中のsenderのid
  text = "富田のオススメランチを教えるよ！カテゴリーと位置情報からレストランを検索します。レストランを検索したい場合は、「レストラン検索」と話しかけてね！"

  content = {
    recipient: {id: sender},
    message: {text: text}
  }
  request_body = content.to_json

  #オウム返しの返信をPOSTする（返す）
  RestClient.post FB_ENDPOINT, request_body, content_type: :json, accept: :json
  status 201
  body ''
end
