# -*- coding: utf-8 -*-
require 'uri'
require 'timeout'
require 'resolv-replace'
require 'net/http'
Net::HTTP.version_1_2
require 'fileutils'
require 'date'
require 'kconv'
require 'lib/progressbar'
require 'pp'
require 'rubygems'
require 'sqlite3'

class Downloader
  CODES_FILE = "dat/codes.txt"
  FROM_DATE = Date.new(2008, 1, 1)
  RE_STOCK = %r{
<td><small>(\d+)年(\d+)月(\d+)日</small></td>\n
<td><small>([\d,]+)</small></td>\n
<td><small>([\d,]+)</small></td>\n
<td><small>([\d,]+)</small></td>\n
<td><small><b>([\d,]+)</b></small></td>\n
<td><small>([\d,]+)</small></td>\n
<td><small>([\d,]+)</small></td>
}xmi

  def initialize(opt)
    @encoding = (RUBY_PLATFORM =~ /mswin(?!ce)|mingw|cygwin|bccwin/i) ? "tosjis" : "toutf8"
    @path = opt[:path] || "dat"
    FileUtils.mkdir_p(@path) unless File.directory?(@path)
    @from_date = opt[:from] || FROM_DATE
    @mode = opt[:mode] || 'append' # or write
    @codes = load_stock_codes
  end

  def get_stock_code_from_kdbcom
    html = nethttp("http://k-db.com/site/download.aspx").toutf8
    links = html.scan(%r{location.href='(download.aspx\?date=\d{4}-\d{2}-\d{2}-d)'}i)
    return nil if links == []
    html = nethttp("http://k-db.com/site/#{links[0]}").toutf8
    open(CODES_FILE, "w").write(html)
  end

  def load_stock_codes
    get_stock_code_from_kdbcom unless File.exist?(CODES_FILE)
    text = open(CODES_FILE).read
    text.split("\n")[2..-1].inject({}) do |h, line|
      code, market,  company = line.split(",")[0...3]
      h[code.to_i] = company.to_s.strip.send(@encoding)
      h
    end
  end

  def get_page_data(uri)
    html = nethttp(uri)
    return [] if html.nil?
    company = html.toutf8.scan(%r{<div class="name"><b class="yjXL">(.+?)</b><span class="yjM">})
    stocks = html.toutf8.scan(RE_STOCK)
    [stocks, company.to_s.strip.send(@encoding)]
  end
  
  def nethttp(uri_str)
    timeout(3) do 
      response = Net::HTTP.get_response(URI.parse(uri_str))
      case response
      when Net::HTTPSuccess
        response.body
      else
        puts response.error!
        sleep 3
      end
    end
  rescue Timeout::Error
    sleep 3 # "Timeout: #{uri_str}"
    retry
  rescue => e
    puts "Error: #{e}: #{uri_str}"
  end
  
  def array_to_csv(array)
    array.reverse!
    array.map{|line| line.map{|e| e.gsub(/,/,"") }.join(",") }.join("\n") + "\n"
  end
  
  def create_uri(code, from, to, num)
    "http://table.yahoo.co.jp/t?c=#{from.year}&a=#{from.month}&b=#{from.day}&" + 
      "f=#{to.year}&d=#{to.month}&e=#{to.day}&g=d&s=#{code}&y=#{num}&z=&x=sb"
  end
  
  def get_last_date(filename)
    filepath = File.join(@path, filename)
    return @from_date unless File.exist?(filepath)
    d = open(filepath , "r" ).read.strip.split("\n")
    return FROM_DATE if d.empty?

    tail = d[d.length-1].split(",")[0...3].map{|n| n.to_i }
    Date.new(tail[0], tail[1], tail[2])
  end

  def run(codes=[])
    to_date = Date.today
    codes = @codes.map{|k, v| k }.uniq if codes.empty?
    size = codes.size
    puts "株価データのダウンロード中です...".send(@encoding)

    pbar = ProgressBar.new("Total", size)
    codes.sort.each_with_index do |code, i|
      pbar.inc
      from_date = @mode == 'append' ? get_last_date("#{code}.csv") + 1 : FROM_DATE
      next if from_date > to_date

      pages = []
      0.step(to_date - from_date , 50) do |j|
        uri = create_uri(code, from_date, to_date, j)
        page, company = get_page_data(uri)
        break if page == []

        @codes[code] = company
        pages += page
      end

      mode = @mode == 'append' ? 'a' : 'w'
      open(File.join(@path, "#{code}.csv"), mode) do |f|
        f.write(array_to_csv(pages)) if pages != []
      end
    end
    pbar.finish
    puts "ダウンロードが終了しました".send(@encoding)
  end
end

class Database
  DBFILE = 'dat/stocks.db'
  CODES_FILE = "codes.txt"

  def initialize(init=false)
    File.unlink DBFILE if File.exists?(DBFILE) and init
    @db = SQLite3::Database.new(DBFILE)
    @codes = create_hash_table
    create_table if init
  end

  def create_hash_table
    text = open(CODES_FILE).read
    text.split("\n")[2..-1].inject({}) do |h, line|
      code, market,  company = line.split(",")[0...3]
      h[code.to_i] = company.to_s.strip.toutf8
      h
    end
  end

  def codes
    @codes.each_key.sort
  end

  def create_table
    @db.execute(<<-"EOD")
      create table stock (
        code integer,
        date integer,
        open integer,
        high integer,
        low integer,
        close integer,
        volume integer
      );
      EOD
    @db.execute(<<-"EOD")
      create index stock_idx on stock(
        code, date
      );
      EOD
  end

  def trans_begin
    @db.execute(<<-"EOD")
      begin
      EOD
  end

  def trans_commit
    @db.execute(<<-"EOD")
      commit
      EOD
  end
  
  def insert(code, date, open, high, low, close, volume)
    @db.execute(<<-"EOD")
      insert into stock values(#{code}, #{date}, #{open}, #{high}, #{low}, #{close}, #{volume})
      EOD
  end

  def last(code)
    @db.execute(<<-"EOD")[0]
      select * from stock where code = #{code} order by date desc
      EOD
  end

  def select_by_code(code)
    @db.execute(<<-"EOD")
      select * from stock where code = #{code} order by date
      EOD
  end

  def close_prices(code)
    a = select_by_code(code)[-25..-1]
    a.nil? ? [] : a.map{|n| n[5].to_i }
  end

  def select_by_code_and_date(code, date)
    @db.execute(<<-"EOD")
      select * from stock where code = #{code} and date = #{date}
      EOD
  end

  def csv_to_database(path='dat')
    puts "データーベースにインポート中です..."
    stock = Database.new(true)
    
    files = Dir.glob(File.join(path, "*.csv"))
    pbar = ProgressBar.new(DBFILE, files.size)
    stock.trans_begin
    files.each_with_index do |f, i|
      code = File.basename(f).scan(/(\d{4}).csv/).to_s.to_i
      ds = open(f).read.split("\n").map{|line| line.split(",").map{|s| s.to_i} }
      pbar.inc
      next if ds.empty?
      ds.each do |d|
        date = sprintf("%04d%02d%02d", d[0], d[1], d[2]).to_i
        stock.insert(code, date, d[3], d[4], d[5], d[6], d[7])
      end
    end
    stock.trans_commit
    pbar.finish
  end
end


if $0 == __FILE__
  Downloader.new(:path => 'dat', :from => Date.new(2008, 1, 1), :mode => 'append').run
  Database.new(true).csv_to_database
  system('say task is finished.')
end
