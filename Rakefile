require 'rubygems'
require 'bundler/setup'
require 'rake'
require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.libs << 'test/lib'
  t.pattern = 'test/*.rb'
end
