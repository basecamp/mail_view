require 'test/unit'
require 'rack/test'

require 'mail_view'
require 'mail'
require 'tmail'
require 'cgi'  # For CGI.unescapeHTML

class TestMailView < Test::Unit::TestCase
  include Rack::Test::Methods

  class Preview < MailView
    def plain_text_message
      Mail.new do
        to 'josh@37signals.com'
        body 'Hello'
      end
    end

    def plain_text_message_with_display_names
      Mail.new do
        to 'Josh Peek <josh@37signals.com>'
        from 'Test Peek <test@foo.com>'
        reply_to 'Another Peek <another@foo.com>'
        body 'Hello'
      end
    end

    def tmail_plain_text_message_with_display_names
      TMail::Mail.parse(plain_text_message_with_display_names.to_s)
    end

    def html_message
      Mail.new do
        to 'josh@37signals.com'

        content_type 'text/html; charset=UTF-8'
        body '<h1>Hello</h1>'
      end
    end

    def tmail_html_message
      TMail::Mail.parse(html_message.to_s)
    end

    def multipart_alternative
      Mail.new do
        to 'josh@37signals.com'

        text_part do
          body 'This is plain text'
        end

        html_part do
          content_type 'text/html; charset=UTF-8'
          body '<h1>This is HTML</h1>'
        end
      end
    end

    def multipart_alternative_text_default
      Mail.new do
        to 'josh@37signals.com'

        html_part do
          content_type 'text/html; charset=UTF-8'
          body '<h1>This is HTML</h1>'
        end

        text_part do
          body 'This is plain text'
        end

      end
    end

    def tmail_multipart_alternative
      TMail::Mail.parse(multipart_alternative.to_s)
    end

    def nested_multipart_message
      container = Mail::Part.new
      container.content_type = 'multipart/alternative'
      container.text_part { body 'omg' }
      container.html_part do
        content_type 'text/html; charset=UTF-8'
        body '<h1>Hello</h1>'
      end

      mail = Mail.new
      mail.add_part container
      mail
    end
  end

  class ISayHelloAndYouSayGoodbyeInterceptor
    Mail.register_interceptor self
    @@intercept = false

    def self.intercept
      @@intercept = true
      yield
    ensure
      @@intercept = false
    end

    def self.delivering_email(message)
      if @@intercept
        message.body = message.body.to_s.gsub('Hello', 'Goodbye')
      end
    end
  end

  def app
    Preview
  end

  def iframe_src_match(action)
    /<iframe[^>]* src="#{Regexp.escape(action)}"[^>]*><\/iframe>/
  end

  def unescaped_body
    CGI.unescapeHTML last_response.body
  end

  def test_index
    get '/'
    assert last_response.ok?

    assert_match(/plain_text_message/, last_response.body)
    assert_match(/html_message/, last_response.body)
    assert_match(/multipart_alternative/, last_response.body)
  end

  def test_not_found
    get '/missing'
    assert last_response.not_found?
  end

  def test_plain_text_message
    get '/plain_text_message'
    assert last_response.ok?
    assert_match(/Hello/, last_response.body)
  end

  def test_plain_text_message_with_to_display_name
    get '/plain_text_message_with_display_names'
    assert last_response.ok?

    assert_match(/Josh Peek <josh@37signals.com>/, unescaped_body)
  end

  def test_plain_text_message_with_from_display_name
    get '/plain_text_message_with_display_names'
    assert last_response.ok?

    assert_match(/Test Peek <test@foo.com>/, unescaped_body)
  end

  def test_plain_text_message_with_reply_to_display_name
    get '/plain_text_message_with_display_names'
    assert last_response.ok?

    assert_match(/Another Peek <another@foo.com>/, unescaped_body)
  end

  def test_html_message
    get '/html_message'
    assert last_response.ok?
    assert_match(iframe_src_match('/html_message.html?body=1'), last_response.body)

    get '/html_message.html?body=1'
    assert last_response.ok?
    assert_match(/<h1>Hello<\/h1>/, last_response.body)
  end

  def test_nested_multipart_message
    get '/nested_multipart_message'
    assert last_response.ok?
    assert_match(iframe_src_match('/nested_multipart_message.html?body=1'), last_response.body)

    get '/nested_multipart_message?body=1'
    assert last_response.ok?
    assert_match(/<h1>Hello<\/h1>/, last_response.body)
  end

  def test_multipart_alternative
    get '/multipart_alternative'
    assert last_response.ok?
    assert_match(iframe_src_match('/multipart_alternative.html?body=1'), last_response.body)
    assert_match(/View plain text version/, last_response.body)

    get '/multipart_alternative.html?body=1'
    assert last_response.ok?
    assert_match(/<h1>This is HTML<\/h1>/, last_response.body)
  end

  def test_multipart_alternative_as_html
    get '/multipart_alternative.html'
    assert last_response.ok?
    assert_match(iframe_src_match('/multipart_alternative.html?body=1'), last_response.body)
    assert_match(/View plain text version/, last_response.body)

    get '/multipart_alternative.html?body=1'
    assert last_response.ok?
    assert_match(/<h1>This is HTML<\/h1>/, last_response.body)
  end

  def test_multipart_alternative_as_text
    get '/multipart_alternative.txt'
    assert last_response.ok?

    assert_match(/This is plain text/, last_response.body)
    assert_match(/View HTML version/, last_response.body)
  end

  def test_multipart_alternative_text_as_default
    get '/multipart_alternative_text_default'
    assert last_response.ok?

    assert_match(/This is plain text/, last_response.body)
    assert_match(/View HTML version/, last_response.body)
  end

  def test_interceptors
    ISayHelloAndYouSayGoodbyeInterceptor.intercept do
      get '/plain_text_message'
    end

    assert last_response.ok?
    assert_match(/Goodbye/, last_response.body)
  end

  unless RUBY_VERSION >= '1.9'
    def test_tmail_html_message
      get '/tmail_html_message'
      assert last_response.ok?
      assert_match(iframe_src_match('/tmail_html_message.html?body=1'), last_response.body)

      get '/tmail_html_message.html?body=1'
      assert last_response.ok?
      assert_match(/<h1>Hello<\/h1>/, last_response.body)
    end

    def test_tmail_multipart_alternative
      get '/tmail_multipart_alternative'
      assert last_response.ok?
      assert_match(/View plain text version/, last_response.body)
      assert_match(iframe_src_match('/tmail_multipart_alternative.html?body=1'), last_response.body)

      get '/tmail_multipart_alternative.html?body=1'
      assert last_response.ok?
      assert_match(/<h1>Hello<\/h1>/, last_response.body)
    end

    def test_tmail_plain_text_message_with_to_display_name
      get '/tmail_plain_text_message_with_display_names'
      assert last_response.ok?

      assert_match(/Josh Peek <josh@37signals.com>/, unescaped_body)
    end

    def test_tmail_plain_text_message_with_from_display_name
      get '/tmail_plain_text_message_with_display_names'
      assert last_response.ok?

      assert_match(/Test Peek <test@foo.com>/, unescaped_body)
    end

    def test_tmail_plain_text_message_with_reply_to_display_name
      get '/tmail_plain_text_message_with_display_names'
      assert last_response.ok?

      assert_match(/Another Peek <another@foo.com>/, unescaped_body)
    end

  end
end
