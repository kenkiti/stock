# -*- coding: utf-8 -*-
require 'kconv'

FILE_CODES = 'dat/codes.txt'
FILE_CHECK = 'boro_kabu.txt'

def open_check_file
  open(FILE_CHECK).read.split("\n").map{|n| n.to_i }
end

def market_hash
  h = {}
  markets = {'東証' => 'T', 
    '大証' => 'OS', 
    'ＪＱ' => 'Q', 
    'ＨＣ' => 'OJ' }

  open(FILE_CODES).read.split("\n").each do |row|
    cols = row.split(",")
    next unless cols[0] =~ /\d{4}$/
    market = ""
    markets.map{|k, v| market = v if cols[1] =~ /#{k}/}
    h[cols[0].to_i] = market
  end
  h
end

class RakutenRSS
  def initialize
    @h = market_hash
  end

  def header
    s = "銘柄コード," + 
      "銘柄名称," + 
      "現在値ティック," + 
      "前日終値," +
      "最良売気配値," +
      "最良買気配値," + 
      "現在値," + 
      "始値," + 
      "高値," +
      "安値," +
      "前場始値," +
      "前場高値," +
      "前場安値," +
      "前場終値," +
      "後場始値," +
      "後場高値," +
      "後場安値"
    s.tosjis
  end

  def list(code)
    s = "=RSS|'#{code}.#{@h[code]}'!銘柄コード," + 
      "=RSS|'#{code}.#{@h[code]}'!銘柄名称," + 
      "=RSS|'#{code}.#{@h[code]}'!現在値ティック," + 
      "=RSS|'#{code}.#{@h[code]}'!前日終値," +
      "=RSS|'#{code}.#{@h[code]}'!最良売気配値," +
      "=RSS|'#{code}.#{@h[code]}'!最良買気配値," + 
      "=RSS|'#{code}.#{@h[code]}'!現在値," + 
      "=RSS|'#{code}.#{@h[code]}'!始値," + 
      "=RSS|'#{code}.#{@h[code]}'!高値," +
      "=RSS|'#{code}.#{@h[code]}'!安値," +
      "=RSS|'#{code}.#{@h[code]}'!前場始値," +
      "=RSS|'#{code}.#{@h[code]}'!前場高値," +
      "=RSS|'#{code}.#{@h[code]}'!前場安値," +
      "=RSS|'#{code}.#{@h[code]}'!前場終値," +
      "=RSS|'#{code}.#{@h[code]}'!後場始値," +
      "=RSS|'#{code}.#{@h[code]}'!後場高値," +
      "=RSS|'#{code}.#{@h[code]}'!後場安値"
    s.tosjis
  end
  
  def write(opt)
    filepath = File.expand_path(opt[:filepath]) || 'rss.csv'
    codes = open_check_file
    text = "#{header}\n" + codes.map {|code| list(code) }.join("\n")
    open(filepath, 'w').write(text)
  end

end

rss = RakutenRSS.new
rss.write({:filepath => "~/Dropbox/rss.csv"})

__END__
*** ウップス
（１）買いのルール
今日の始値が前日の安値よりも安く始まり、前日の安値を上抜いたら買い。
（２）売りのルール
今日の始値が前日の高値よりも高く始まり、前日の高値を下抜いたら売り。

前日が陽線であったか、陰線であったか、ATR の値等でフィルターをかける。
対象にする銘柄で必要な要素は、出来高が大き過ぎずに値幅が大きい事です。
低位大型株は向きません。ADX ギャッパー。

主な手仕舞い。
（１）当日の大引け
（２）翌日の大引け
（３）翌日の寄り付き
（４）最初に利の乗った寄り付き
（５）利益目標達成時
（６）損切り水準に達した時

*** First 1 Hour Range Break
その日の最初の１時間のレンジを上方にブレイクしたら買い、下方にブレイクしたら売り

*** 回転日数レンジブレイク
