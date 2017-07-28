Bundler.require
require 'logger'

class Scraper
  class BraintreeScraper
    def initialize(username, password, users)
      @host = 'https://www.braintreegateway.com'
      @username = username
      @password = password
      @agent = Mechanize.new
      @pages = {}
      @users = users
    end

    def login
      page = @agent.get("#{@host}/login")
      page.form.login = @username
      page.form.password = @password
      page = page.form.submit
      @merchant_id = page.uri.path.split('/')[2]
      page
    end

    def scrape_all_users
      login
      page_number = 1
      while true do
        page = @agent.get("#{@host}/users?merchant_id=#{@merchant_id}&page=#{page_number}")
        print "scraping page #{page_number}"
        rows = scrape_users_page(page)
        break if rows == 0
        puts
        page_number =+ 1
      end
      scrape_roles
    end

    def scrape_users_page(page)
      rows = page.search('.sep tr')
      rows.each do |row|
        begin
          cells = row.search('td')
          next if cells.empty?
          username = cells.first.text.strip
          url = "#{@host}/#{cells.first.search('a').first.attributes['href'].value}"
          name = cells[1].text
          email = cells[2].text
          status = cells[3].text
          id = url.split('/').last
          # api_access =
          @users << AuthorizedUser.new(name, username, email, id, url, status, [], [])
          print '.'
        rescue => e
          print 'E'
          File.open('scrape.err.log', 'a') { |f| f.puts [e.message, e.backtrace].join("\n") }
        end
      end
      rows.length
    end

    def scrape_roles
      roles_page = @agent.get("#{@host}/merchants/#{@merchant_id}/roles")
      roles_page.search('#roles.sep a').each do |element|
        url = element.attributes['href'].value
        scrape_role_page(@agent.get("#{@host}#{url}")) unless url[-4..-1] == 'edit'
      end
    end

    def scrape_role_page(page)
      role_name = page.search('h2').first.text
      print "scraping roles for #{role_name}"
      page.search('div.block a').each do |element|
        id = element.attributes['href'].value.split('/').last
        user = @users.detect { |u| u.id == id }
        if user.nil?
          puts "Unknown user id #{id} on role page #{role_name}"
        else
          user.roles << role_name
        end
        print '.'
      end
      puts
    end

    def scrape_all_active_users_mid_access
      @users.select { |u| u.url =~ /braintree/ && u.status =~ /active/ }.
        tap { |a| puts "scraping #{a.length} Active Braintree user pages for MID permissions" }.
        each_with_index do |u, i|
        print '.' if (i + 1).divmod(10)[1] == 0
        scrape_user_page(u)
      end
    end

    def scrape_user_page(user)
      user_page = @agent.get(user.url)
      elements = user_page.search('[id^=merchant_account] [type=checkbox]')
      all = elements[0]
      all_checked = all.attributes.keys.include?('checked')
      if all_checked
        user.mids << 'ALL'
      else
        user.mids << elements[1..-1].select { |e| e.attributes.keys.include?('checked') }.map { |e| e.parent.text.strip }
        user.mids.flatten!
      end
    end
  end

  attr_accessor :host, :agent, :users

  def initialize(username, password)
    @username = username
    @password = password
  end

  def scrape_all
    @users = [] # init here so reload doesn't dupe everything
    BraintreeScraper.new(@username, @password, @users).scrape_all_users
  end

  def scrape_user_details
    BraintreeScraper.new(@username, @password, @users).scrape_all_active_users_mid_access
  end
end

class AuthorizedUser < Struct.new(:name, :username, :email, :id, :url, :status, :roles, :mids)
  def to_s
    "#{name.ljust(35)}#{username.ljust(35)}#{email.ljust(35)} #{status}"
  end

  def color
    case status
    when /active/
      :bold
    when /suspended/
      :red
    else
      nil
    end
  end

  def matches(query)
    re = /#{query}/i
    name =~ re || username =~ re || email =~ re || status =~ re || id =~ re || !((roles || []).grep(re).empty?)
  end
end

class Users < Thor
  include Thor::Actions

  default_task :search

  desc('search', 'search for a Braintree user. QUERY can match anything')

  def search
    login_and_scrape
  end

  private

  def login_and_scrape
    username = ask 'Braintree Username:'
    password = ask 'Braintree Password:'
    @scraper = Scraper.new(username, password)
    @include_roles = false
    scrape
  end

  def scrape
    @scraper.scrape_all
    @users = @scraper.users
    prompt
  end

  def run(queries)
    @found = []
    Array(queries).each do |query|
      @users.each do |user|
        @found << user if user.matches(query)
      end
    end
    @found.each_with_index do |user, index|
      say "[#{index}] #{user.to_s}", user.color
      say "  #{user.roles.join(', ')}", user.color if @include_roles
    end
    prompt
  end

  def report
    require 'csv'
    filename = 'user.report.csv'
    CSV.open(filename, 'w') do |f|
      f << %w(Name Username Email ID Role)
      @users.select { |u| u.status == 'active' }.each do |user|
        user.roles.each do |role|
          f << [user.name, user.username, user.email, user.id, role]
        end
      end
    end
    puts "#{filename} written"
    prompt
  end

  def prompt
    prompt_text = @found && !@found.empty? ? 'Type number to open user or new search text:' : 'Enter search text:'
    result = ask prompt_text
    # this isn't stack friendly, btw :)
    case result
    when /\A\d+\z/
      user = @found[result.to_i]
      `open #{user.url}` unless user.nil?
      prompt
    when /pry/
      pry.binding
    when 'exit', 'quit'
      return
    when 'reload'
      scrape
    when 'roles'
      @include_roles = !@include_roles
      prompt
    when 'report'
      report
    when /\Aany (.*)\z/
      run($1.split(',').map(&:strip))
    when /^\s*$/
      prompt
    when 'details'

    else
      run(result)
    end
  rescue => e
    say e.message
    prompt
  end
end
