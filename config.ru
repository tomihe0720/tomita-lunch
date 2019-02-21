require './app'
$stdout.sync = true # この一行を追加する
run Sinatra::Application
