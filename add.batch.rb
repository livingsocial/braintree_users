# Designed to be used in Pry ... just cuz.
# bundle exec pry
# require './add.batch'

Bundler.require

class BraintreeAdder
  attr_reader :agent

  def initialize(username, password, emails)
    @host = 'https://www.braintreegateway.com'
    @username = username
    @password = password
    @agent = Mechanize.new
    @pages = {}
    @emails = emails
  end

  def login
    page = @agent.get("#{@host}/login")
    page.form.login = @username
    page.form.password = @password
    page = page.form.submit
    @merchant_id = page.uri.path.split('/')[2]
    page
  end


  def add_read_only_user
    # The roles are user defined, will have to update accordingly
    add(@emails.pop, {roles: [:read_only]})
  end

  def add_void_refund_user
    # The roles are user defined, will have to update accordingly
    add(@emails.pop, {roles: [:read_only, :void_refund]})
  end

  def add_credit_user
    # The roles are user defined, will have to update accordingly
    add(@emails.pop, {roles: [:read_only, :void_refund, :create]})
  end

  private

  def add(email, options={})
    print "Adding #{email} - "
    page = @agent.get("#{@host}/merchants/#{@merchant_id}/users/new")
    form = page.forms[1] # entry form

    form.field_with(name: 'user[email]').value = email

    form.checkbox_with(name: 'user[api_access]').checked = false

    # ensure all rights disabled first - yes they all have the same name
    form.checkboxes_with(name: 'user[role_ids][]').each { |cb| cb.checked = false }

    # TODO: Roles are all user defined, you'll need to update this hash to match.
    role_checkbox_values = {
      # read_only: 'abcdsnth1234',
      # void_refund: 'abcdsnth2345',
      # create: 'abcdsnth3456'
    }

    options[:roles].each do |role|
      print "#{role} - "
      form.checkbox_with(value: role_checkbox_values[role]).checked = true
    end

    # TODO: You can select All merchant accounts with the following line:
    # print 'all merchant accounts - '
    # form.checkboxes.detect { |cb| cb.name == 'user[grant_all_merchant_accounts]' }.checked = true

    # TODO: Or setup specific merchant accounts to select
    merchant_accounts = [
      # 100, # MerchantsUSD,
      # 101, # MerchantsCAD
    ]

    print 'merchant accounts - '
    merchant_accounts.each do |merchant_id|
      form.checkboxes.detect { |cb| cb.name == "merchant_accounts[#{merchant_id}]" }.checked = true
    end

    form.submit.tap { puts 'Submitted' }
  end
end

def execute
  # One line per email address
  new_accounts = File.readlines('users_to_add.txt')
  new_accounts.map! { |ln|
    if ln =~ /,/
      last, first = ln.strip.split(',')
      "#{first} #{last}"
    else
      ln
    end
  }

  print 'Braintree Username: '
  username = gets.chomp

  print 'Braintree Password: '
  pswd = gets.chomp

  ba = BraintreeAdder.new(username, pswd, new_accounts)
  ba.login
  ba
end

if __FILE__ == $0
  execute
end
