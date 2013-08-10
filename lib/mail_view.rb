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

    elsif request.path =~ /([\w_]+)(\.\w+)?\z/
      name, ext = $1, $2
      format = Rack::Mime.mime_type(ext, nil)
      missing_format = ext && format.nil?

      if actions.include?(name) && !missing_format
        mail = build_mail(name)

        # Requested a specific bare MIME part. Render it verbatim.
        if part_type = request.params['part']
          if part = find_part(mail, part_type)
            body = part.body
            body = body.decoded if body.respond_to?(:decoded)
            ok body, part.content_type
          else
            not_found
          end

        # Otherwise, show our message headers & frame the body.
        else
          part = find_preferred_part(mail, [format, 'text/html', 'text/plain'])
          ok email_template.render(Object.new, :name => name, :mail => mail, :part => part, :part_url => part_body_url(part))
        end
      else
        not_found
      end

    else
      not_found(true)
    end
  end

  protected
    def actions
      public_methods(false).map(&:to_s).sort - ['call']
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
    def ok(body, content_type = 'text/html')
      [200, {"Content-Type" => content_type}, [body]]
    end

    def not_found(pass = false)
      if pass
        [404, {"Content-Type" => "text/html", "X-Cascade" => "pass"}, ["Not Found"]]
      else
        [404, {"Content-Type" => "text/html"}, ["Not Found"]]
      end
    end

    def build_mail(name)
      mail = send(name)
      Mail.inform_interceptors(mail) if defined? Mail
      mail
    end

    def find_preferred_part(mail, formats)
      found = nil
      formats.find { |f| found = find_part(mail, f) }
      found || mail
    end

    def part_body_url(part)
      '?part=%s' % Rack::Utils.escape([part.main_type, part.sub_type].compact.join('/'))
    end

    def find_part(mail, matching_content_type)
      if mail.multipart?
        if matching_content_type.nil? && mail.sub_type == 'alternative'
          mail.parts.last
        else
          found = nil
          mail.parts.find { |part| found = find_part(part, matching_content_type) }
          found
        end
      elsif matching_content_type && mail.content_type.to_s.match(matching_content_type)
        mail
      end
    end
end
