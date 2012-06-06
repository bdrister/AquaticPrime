Gem::Specification.new do |s|
  s.name = 'aquaticprime'
  s.version = '1.1.0'
  s.authors = ['John Labovitz', 'Benjamin Rister']
  s.email = ['johnl@johnlabovitz.com', 'aquaticprime@decimus.net']
  s.summary = 'AquaticPrime is a cryptographically secure licensing method for shareware applications. The Ruby implementation currently only generates licenses, and is intended for use in online stores.'
  s.homepage = 'http://github.com/bdrister/AquaticPrime'
  s.add_dependency('plist', '~>3.1')
  s.files = [ 'README',
              'LICENSE',
              'lib/aquaticprime.rb' ]
end