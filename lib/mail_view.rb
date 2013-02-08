require 'erb'
require 'tilt'

require 'rack/mime'
require 'rack/request'

class MailView
  autoload :Mapper, 'mail_view/mapper'

  class << self
    def default_email_template_path
      File.expand_path('../mail_view/email.html.erb', __FILE__)
    end

    def default_index_template_path
      File.expand_path('../mail_view/index.html.erb', __FILE__)
    end

    def call(env)
      new.call(env)
    end
  end

  def call(env)
    request = Rack::Request.new(env)

    if request.path_info == "" || request.path_info == "/"
      links = self.actions.map do |action|
        [action, "#{request.script_name}/#{action}"]
      end

      ok index_template.render(Object.new, :links => links)

    elsif request.path_info =~ /([\w_]+)(\.\w+)?$/
      name   = $1
      format = $2 || ".html"

      if actions.include?(name)
        mail = send(name)
        response = if request.params["body"]
                     render_mail_body(mail, format)
                   else
                     render_mail(name, mail, format, request)
                   end
        ok response
      else
        not_found
      end

    else
      not_found(true)
    end
  end

  protected
    def actions
      public_methods(false).map(&:to_s) - ['call']
    end

    def email_template
      Tilt.new(email_template_path)
    end

    def email_template_path
      self.class.default_email_template_path
    end

    def index_template
      Tilt.new(index_template_path)
    end

    def index_template_path
      self.class.default_index_template_path
    end

  private
    def ok(body)
      [200, {"Content-Type" => "text/html"}, [body]]
    end

    def not_found(pass = false)
      if pass
        [404, {"Content-Type" => "text/html", "X-Cascade" => "pass"}, ["Not Found"]]
      else
        [404, {"Content-Type" => "text/html"}, ["Not Found"]]
      end
    end

    def render_mail(name, mail, format, request)
      path_with_format = if request.path =~ /#{Regexp.escape(format)}$/
                           request.path
                         else
                           "#{request.path}#{format}"
                         end

      email_template.render(Object.new,
                            :name => name,
                            :mail => mail,
                            :body_part => body_part(mail, format),
                            :body_only_path => "#{path_with_format}?body=1")
    end

    def render_mail_body(mail, format)
      body_part(mail, format).body
    end

    def body_part(mail, format)
      part = mail

      if mail.multipart?
        content_type = Rack::Mime.mime_type(format)
        part = if mail.respond_to?(:all_parts)
                 mail.all_parts.find { |part| part.content_type.match(content_type) } || mail.parts.first
               else
                 mail.parts.find { |part| part.content_type.match(content_type) } || mail.parts.first
               end
      end

      part
    end

end
