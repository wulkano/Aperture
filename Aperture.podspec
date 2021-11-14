Pod::Spec.new do |s|
	s.name = 'Aperture'
	s.version = '1.0.0'
	s.summary = 'Record the screen on macOS'
	s.license = 'MIT'
	s.homepage = 'https://github.com/wulkano/Aperture'
	s.social_media_url = 'https://twitter.com/wulkanocom'
	s.authors = { 'Sindre Sorhus' => 'sindresorhus@gmail.com', 'Matheus Fernandes' => 'github@matheus.top' }
	s.source = { :git => 'https://github.com/wulkano/Aperture.git', :tag => "v#{s.version}" }
	s.source_files = 'Sources/**/*.swift'
	s.swift_version = '5.5'
	s.platform = :macos, '10.13'
end
