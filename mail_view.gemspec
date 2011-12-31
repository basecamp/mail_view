Gem::Specification.new do |s|
  s.name = 'mail_view'
  s.version = '1.0.1'
  s.author = 'Josh Peek'
  s.email = 'josh@joshpeek.com'
  s.summary = 'Visual email testing'
  s.homepage = 'https://github.com/37signals/mail_view'

  s.add_dependency 'tilt'

  s.files = Dir["#{File.dirname(__FILE__)}/*/**"]
end
