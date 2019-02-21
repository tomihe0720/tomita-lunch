require 'sinatra'
require 'sinatra/reloader'
require 'json'
require 'rest_client'

FB_ENDPOINT = "https://graph.facebook.com/v2.6/me/messages?access_token=" + "EAAEIr8ppJUYBALtJmTQ7zk6zoQbKXHBoHqL3iOalZCcC1WtjzIqOvHYcasMZAuZBvKSjxt59y3MiDQVNjUcTP0kP85lzZCGg4rLW9MCOvwjb6QnL469vmnwbexVeFFStRauUqovl94ZA3XtxlavW97Xp5iAhYCFn0W9r0ZAeQcmgZDZD"
GNAVI_KEYID = "3b5b8c8869545e8ab33ee49b2d7eb592"
GNAVI_CATEGORY_LARGE_SEARCH_API = "https://api.gnavi.co.jp/master/CategoryLargeSearchAPI/v3/"
GNAVI_SEARCHAPI = "https://api.gnavi.co.jp/RestSearchAPI/v3/"


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

  if message["message"]["text"] == "レストラン検索"
    categories = filter_categories
    request_body = set_quick_reply_of_categories(sender, categories)
    RestClient.post FB_ENDPOINT, request_body, content_type: :json, accept: :json

  elsif !message["message"]["quick_reply"].nil?

     # カテゴリーコードは引き回すのでグローバル変数として定義
     # ローカル変数だと別メソッドからは呼び出せません
     $requested_category_code = message["message"]["quick_reply"]["payload"]
     request_body = set_quick_reply_of_location(sender)
     RestClient.post FB_ENDPOINT, request_body, content_type: :json, accept: :json

   elsif !message["message"]["attachments"].nil? && message["message"]["attachments"][0]["type"] == 'location' && !$requested_category_code.nil?
   lat, long = get_location(message)
   restaurants = get_restaurants(lat, long, $requested_category_code)
   elements = set_restaurants_info(restaurants)
   request_body = set_reply_of_restaurant(sender, elements)
   RestClient.post FB_ENDPOINT, request_body, content_type: :json, accept: :json

  else

    text = "富田のオススメグルメを教えるよ:-)カテゴリーと位置情報からレストランを検索します。レストランを検索したい場合は、「レストラン検索」と話しかけてね！"
    content = {
      recipient: {id: sender},
      message: {text: text}
    }
    request_body = content.to_json
    RestClient.post FB_ENDPOINT, request_body, content_type: :json, accept: :json
  end
  status 201
  body ''
end

helpers do
  def get_categories
    response = JSON.parse(RestClient.get GNAVI_CATEGORY_LARGE_SEARCH_API + "?keyid=#{GNAVI_KEYID}")
    categories = response["category_l"]
    categories
  end

  def filter_categories
  categories = []
  get_categories.each_with_index do |category, i|
    if i < 11
      hash = {
        content_type: 'text',
        title: category["category_l_name"],
        payload: category["category_l_code"], # ぐるなびAPIで取得したコード
      }
      p hash
      categories.push(hash)
    else
      p "11回目は配列に入れない"
    end
  end
  categories
  end

  def set_quick_reply_of_categories sender, categories
  {
    recipient: {
      id: sender
    },
    message: {
      text: '富田のオススメ教えちゃうぞ :P なにが食べたいか教えて?',
      quick_replies: categories
    }
  }.to_json
  end

  def set_quick_reply_of_location sender
  {
    recipient: {
      id: sender
    },
    message: {
      text: "位置情報を送信してね (^^^)",
      quick_replies: [
        { content_type: "location" }
      ]
    }
  }.to_json
  end

  def get_location message
  lat = message["message"]["attachments"][0]["payload"]["coordinates"]["lat"]
  long = message["message"]["attachments"][0]["payload"]["coordinates"]["long"]
  [lat, long]
  end

  def get_restaurants lat, long, requested_category_code
    # 緯度,経度,カテゴリー,範囲を指定
    params = "?keyid=#{GNAVI_KEYID}&latitude=#{lat}&longitude=#{long}&category_l=#{requested_category_code}&range=3"
    restaurants = JSON.parse(RestClient.get GNAVI_SEARCHAPI + params)
    restaurants
  end

  # APIで取得したレストラン情報をMessengerで送信できる構文に整形
  def set_restaurants_info restaurants
    elements = []
    restaurants["rest"].each do |rest|
        # 三項演算子
      image = rest["image_url"]["shop_image1"].empty? ? "http://techpit-bot.herokuapp.com/images/no-image.png" : rest["image_url"]["shop_image1"]
      elements.push(
        {
          title: rest["name"],
          item_url: rest["url_mobile"],
          image_url: image,
          subtitle: "[カテゴリー: #{rest["code"]["category_name_l"][0]}] #{rest["pr"]["pr_short"]}",
          buttons: [
            {
              type: "web_url",
              url: rest["url_mobile"],
              title: "詳細を見る"
            }
          ]
        }
      )
    end
    elements
  end

  # 整形したレストラン情報をMessengerで返却できる構文に整形
  def set_reply_of_restaurant sender, elements
    {
      recipient: {
        id: sender
      },
      message: {
        attachment: {
          type: 'template',
          payload: {
            template_type: "generic",
            elements: elements
          }
        }
      }
    }.to_json
  end


end
