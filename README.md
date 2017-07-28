# braintree_users

If your company has a large number of Braintree user accounts to
manage, Braintree's Control Panel, well ... sucks. Which I hate to say,
because I've loved everything else about working with Braintree over
the last several years.

This Ruby script uses Mechanize to screenscrape all of the user pages,
allows user search as well as a report of users and their roles, as
well as a separate script to add users.

This does mean that when Braintree updates their user pages, this
script is broken and you'll have to go DOM spelunking again. But, in my
3+ years of using this script, that is a rare event and this has been a
valuable tool.

It was never designed to be anything than a helper for myself and I'm
the only user as of this initial release, so it's pretty warty.

## Usage

### User Search

`bundle exec thor users`

You'll be prompted for username and password (password will be
displayed on screen, yech), then it will auto scrape all your user
pages and leave you at an interactive prompt.

Type in a complete email, name or partial and all matches will be
returned with a numbered menu. Enter the corresponding number on the
next prompt and the url for that user will be opened in your default
browser.

Use `any fee,fi,fo,fum` to search for multiple users.

Use `report` to dump a csv report of all users and roles. Remember
roles are user defined.

Use `reload` to re-scrape everything.

### Add Users

NOTE!! There are a few places of TODO comments in the code that you
will need to adjust to your specific situation if you want to use the
Add script.

Enter one email address per line in a file called users_to_add.txt,
then launch Pry, type in `require './add.batch'`, then `adder =
execute`. This will prompt you for username and password, then you can
call `adder.add_*`. There are some generically named roles in the
script still, but those are user defined and will need to be updated to
whatever you have.
