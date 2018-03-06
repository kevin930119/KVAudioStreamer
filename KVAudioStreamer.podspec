Pod::Spec.new do |s|
s.name         = 'KVAudioStreamer'
s.version      = '1.0.0'
s.summary      = '基于AudioToolBox的音频流媒体播放器'
s.homepage     = 'https://github.com/kevin930119/KVAudioStreamer'
s.license      = 'MIT'
s.authors      = {'Kevin' => '673729631@qq.com'}
s.platform     = :ios, '7.0'
s.source       = {:git => 'https://github.com/kevin930119/KVAudioStreamer.git', :tag => s.version}
s.source_files = 'KVAudioStreamer/*'
s.requires_arc = true
end
