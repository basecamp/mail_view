MailView -- Visual email testing
================================

Preview plain text and html mail templates in your browser without redelivering it every time you make a change.

Rails 4.1
---------
NOTE: MailView is part of Rails 4.1+. No need for the plugin anymore!

* 4.1.0 API docs: http://api.rubyonrails.org/v4.1.0/classes/ActionMailer/Base.html#class-ActionMailer::Base-label-Previewing+emails
* Release notes: http://edgeguides.rubyonrails.org/4_1_release_notes.html#action-mailer-previews
* Pull request: https://github.com/rails/rails/pull/13332/files


Install
-------

Add the gem to your `Gemfile`:

```ruby
  gem 'mail_view', :git => 'https://github.com/basecamp/mail_view.git'
  # or
  gem "mail_view", "~> 2.0.4"
```

And run `bundle install`.

Usage
-----

Since most emails do something interesting with database data, you'll need to write some scenarios to load messages with fake data. Its similar to writing mailer unit tests but you see a visual representation of the output instead.

```ruby
  # app/mailers/mail_preview.rb or lib/mail_preview.rb
  class MailPreview < MailView
    # Pull data from existing fixtures
    def invitation
      account = Account.first
      inviter, invitee = account.users[0, 2]
      Notifier.invitation(inviter, invitee) 
    end

    # Factory-like pattern
    def welcome
      user = User.create!
      mail = Notifier.welcome(user)
      user.destroy
      mail
    end

    # Stub-like
    def forgot_password
      user = Struct.new(:email, :name).new('name@example.com', 'Jill Smith')
      mail = UserMailer.forgot_password(user)
    end
  end
```

Methods must return a [Mail][1] or [TMail][2] object. Using ActionMailer, call `Notifier.create_action_name(args)` to return a compatible TMail object. Now on ActionMailer 3.x, `Notifier.action_name(args)` will return a Mail object.

Routing
-------

A mini router middleware is bundled for Rails 2.x support.

```ruby
  # config/environments/development.rb
  config.middleware.use MailView::Mapper, [MailPreview]
```

For Rails³ you can map the app inline in your routes config.

```ruby
  # config/routes.rb
  if Rails.env.development?
    mount MailPreview => 'mail_view'
  end
```

Now just load up `http://localhost:3000/mail_view`.

Interface
---------

![Plain text view](http://img18.imageshack.us/img18/1066/plaintext.png)
![HTML view](http://img269.imageshack.us/img269/2944/htmlz.png)


[1]: http://github.com/mikel/mail
[2]: http://github.com/mikel/tmail
