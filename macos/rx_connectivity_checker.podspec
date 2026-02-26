Pod::Spec.new do |s|
  s.name             = 'rx_connectivity_checker'
  s.version          = '1.0.1'
  s.summary          = 'macOS implementation of rx_connectivity_checker'
  s.description      = 'Robust reactive connectivity monitoring for macOS.'
  s.homepage         = 'https://github.com/lorenacimpean/rx_connectivity_checker'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Lorena Cimpean' => 'lorenacimpean@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end