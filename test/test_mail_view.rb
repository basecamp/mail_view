require 'test/unit'
require 'rack/test'

require 'mocha/setup'
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
        yield self if block_given?
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

        yield self if block_given?

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

    def multipart_mixed_with_text_and_attachment
      plain_text_message { |mail| add_attachments_to mail }
    end

    def multipart_mixed_with_multipart_alternative_and_attachment
      multipart_alternative { |mail| add_attachments_to mail }
    end

    def add_attachments_to(mail)
      mail.add_file :filename => 'checkbox.png', :content => 'stub'
      mail.add_file :filename => 'foo.vcf', :content => 'stub'
      mail
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

  def iframe_src_match(content_type)
    /<iframe[^>]* src="\?part=#{Regexp.escape(Rack::Utils.escape(content_type))}"[^>]*><\/iframe>/
  end

  def unescaped_body
    CGI.unescapeHTML last_response.body
  end

  def test_index
    get '/'
    assert_match '/plain_text_message', last_response.body
    assert_match '/html_message', last_response.body
    assert_match '/multipart_alternative', last_response.body
  end

  def test_mounted_index
    get '/', {}, 'SCRIPT_NAME' => '/boom'
    assert_match '/boom/plain_text_message', last_response.body
    assert_match '/boom/html_message', last_response.body
    assert_match '/boom/multipart_alternative', last_response.body
  end

  def test_mailer_not_found
    get '/missing'
    assert last_response.not_found?
  end

  def test_format_not_found
    get '/plain_text_message.huzzah'
    assert last_response.not_found?
  end

  def test_mime_part_not_found
    get '/plain_text_message?part=text%2Fhtml'
    assert last_response.not_found?
  end

  def test_plain_text_message
    get '/plain_text_message'
    assert last_response.ok?
    assert_match iframe_src_match(''), last_response.body
    assert_no_match %r(View as), last_response.body

    get '/plain_text_message?part='
    assert last_response.ok?
    assert_match 'Hello', last_response.body
  end

  def test_mounted_plain_text_message
    get '/plain_text_message', {}, 'SCRIPT_NAME' => '/boom'
    assert last_response.ok?
    assert_match iframe_src_match(''), last_response.body
    assert_no_match %r(View as), last_response.body

    get '/boom/plain_text_message?part='
    assert last_response.ok?
    assert_equal 'Hello', last_response.body
  end

  def test_message_header_uses_full_display_names
    get '/plain_text_message_with_display_names'
    assert_match 'Josh Peek <josh@37signals.com>', unescaped_body
    assert_match 'Test Peek <test@foo.com>', unescaped_body
    assert_match 'Another Peek <another@foo.com>', unescaped_body
  end

  def html_message_asserts
    assert last_response.ok?
    assert_match iframe_src_match('text/html'), last_response.body
    assert_no_match %r(View as), last_response.body

    get '/html_message?part=text%2Fhtml'
    assert last_response.ok?
    assert_equal '<h1>Hello</h1>', last_response.body
  end

  def test_html_message
    Net::SMTP.expects(:new).never
    get '/html_message'
    html_message_asserts
  end

  def test_html_message_with_email_addr
    mock_smtp = mock()
    Net::SMTP.expects(:new).returns(mock_smtp)
    mock_smtp.expects(:start)
    get '/html_message?email=barack@whitehouse.gov'
    html_message_asserts
  end

  def nested_multipart_message_asserts
    assert last_response.ok?
    assert_match iframe_src_match('text/html'), last_response.body
    assert_match %r(View as), last_response.body

    get '/nested_multipart_message?part=text%2Fhtml'
    assert last_response.ok?
    assert_equal '<h1>Hello</h1>', last_response.body
  end

  def test_nested_multipart_message
    Net::SMTP.expects(:new).never
    get '/nested_multipart_message'
    nested_multipart_message_asserts
  end

  def test_nested_multipart_message_with_email_addr
    mock_smtp = mock()
    Net::SMTP.expects(:new).returns(mock_smtp)
    mock_smtp.expects(:start)
    get '/nested_multipart_message?email=abe.lincoln@whitehouse.gov'
    nested_multipart_message_asserts
  end

  def multipart_alternative_asserts
    assert last_response.ok?
    assert_match iframe_src_match('text/html'), last_response.body
    assert_match 'View as', last_response.body

    get '/multipart_alternative?part=text%2Fhtml'
    assert last_response.ok?
    assert_equal '<h1>This is HTML</h1>', last_response.body
  end

  def test_multipart_alternative
    Net::SMTP.expects(:new).never
    get '/multipart_alternative'
    multipart_alternative_asserts
  end

  def test_multipart_alternative_with_email_addr
    mock_smtp = mock()
    Net::SMTP.expects(:new).returns(mock_smtp)
    mock_smtp.expects(:start)
    get '/multipart_alternative?email=g.washington@presidentshouse.gov'
    multipart_alternative_asserts
  end

  def multipart_alternative_as_html_asserts
    assert last_response.ok?
    assert_match iframe_src_match('text/html'), last_response.body
    assert_match 'View as', last_response.body

    get '/multipart_alternative.html?part=text%2Fhtml'
    assert last_response.ok?
    assert_equal '<h1>This is HTML</h1>', last_response.body
  end

  def test_multipart_alternative_as_html
    Net::SMTP.expects(:new).never
    get '/multipart_alternative.html'
    multipart_alternative_as_html_asserts
  end

  def test_multipart_alternative_as_html_with_email_addr
    mock_smtp = mock()
    Net::SMTP.expects(:new).returns(mock_smtp)
    mock_smtp.expects(:start)
    get '/multipart_alternative.html?email=jfk@whitehouse.gov'
    multipart_alternative_as_html_asserts
  end

  def multipart_alternative_as_text_asserts
    assert last_response.ok?
    assert_match iframe_src_match('text/plain'), last_response.body
    assert_match 'View as', last_response.body

    get '/multipart_alternative.txt?part=text%2Fplain'
    assert last_response.ok?
    assert_equal 'This is plain text', last_response.body
  end

  def test_multipart_alternative_as_text
    Net::SMTP.expects(:new).never
    get '/multipart_alternative.txt'
    multipart_alternative_as_text_asserts
  end

  def test_multipart_alternative_as_text_with_email_addr
    mock_smtp = mock()
    Net::SMTP.expects(:new).returns(mock_smtp)
    mock_smtp.expects(:start)
    get '/multipart_alternative.txt?email=fdr@whitehouse.gov'
    multipart_alternative_as_text_asserts
  end

  def test_multipart_alternative_text_as_default
    get '/multipart_alternative_text_default'
    assert last_response.ok?
    assert_match iframe_src_match('text/plain'), last_response.body
    assert_match 'View as', last_response.body

    get '/multipart_alternative_text_default?part=text%2Fplain'
    assert last_response.ok?
    assert_equal 'This is plain text', last_response.body
  end

  def test_multipart_mixed_with_text_and_attachment
    get '/multipart_mixed_with_text_and_attachment'
    assert last_response.ok?
    assert_match iframe_src_match('text/plain'), last_response.body
    #assert_no_match %r(View as), last_response.body
    assert_match 'checkbox.png', last_response.body

    get '/multipart_mixed_with_text_and_attachment?part=text%2Fplain'
    assert last_response.ok?
    assert_equal 'Hello', last_response.body
  end

  def test_multipart_mixed_with_multipart_alternative_and_attachment
    get '/multipart_mixed_with_multipart_alternative_and_attachment'
    assert last_response.ok?
    assert_match iframe_src_match('text/html'), last_response.body
    assert_match 'View as', last_response.body
    assert_match 'checkbox.png', last_response.body

    get '/multipart_mixed_with_multipart_alternative_and_attachment?part=text%2Fhtml'
    assert last_response.ok?
    assert_equal '<h1>This is HTML</h1>', last_response.body
  end

  def test_multipart_mixed_with_multipart_alternative_and_attachment_preferring_plain_text
    get '/multipart_mixed_with_multipart_alternative_and_attachment.txt'
    assert last_response.ok?
    assert_match iframe_src_match('text/plain'), last_response.body
    assert_match 'View as', last_response.body
    assert_match 'checkbox.png', last_response.body

    get '/multipart_mixed_with_multipart_alternative_and_attachment.txt?part=text%2Fplain'
    assert last_response.ok?
    assert_equal 'This is plain text', last_response.body
  end

  def test_interceptors
    ISayHelloAndYouSayGoodbyeInterceptor.intercept do
      get '/plain_text_message?part='
    end
    assert_equal 'Goodbye', last_response.body
  end

  unless RUBY_VERSION >= '1.9'
    def test_tmail_html_message
      get '/tmail_html_message'
      assert last_response.ok?
      assert_match iframe_src_match('text/html'), last_response.body

      get '/tmail_html_message?part=text%2Fhtml'
      assert last_response.ok?
      assert_equal '<h1>Hello</h1>', last_response.body
    end

    def test_tmail_multipart_alternative
      get '/tmail_multipart_alternative'
      assert last_response.ok?
      body_path = '/tmail_multipart_alternative?part=text%2Fhtml'
      assert_match iframe_src_match('text/html'), last_response.body
      assert_match 'View as', last_response.body

      get body_path
      assert last_response.ok?
      assert_equal "<h1>This is HTML</h1>\r\n", last_response.body
    end

    def test_tmail_message_header_uses_full_display_names
      get '/tmail_plain_text_message_with_display_names'
      assert_match 'Josh Peek <josh@37signals.com>', unescaped_body
      assert_match 'Test Peek <test@foo.com>', unescaped_body
      assert_match 'Another Peek <another@foo.com>', unescaped_body
    end
  end
end
