Gem::Specification.new do |s|
  s.name = 'mail_view'
  s.version = '2.0.4'
  s.author = 'Josh Peek'
  s.email = 'josh@joshpeek.com'
  s.summary = 'Visual email testing'
  s.homepage = 'https://github.com/37signals/mail_view'

  s.add_dependency 'tilt'

  s.add_development_dependency 'rack-test', '~> 0.6'
  s.add_development_dependency 'mail',      '~> 2.2'
  s.add_development_dependency 'tmail',     '~> 1.2'
  s.add_development_dependency 'rake'

  s.files = %w(init.rb) + Dir['lib/**/*']
end
