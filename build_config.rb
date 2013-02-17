MRuby::Build.new do |conf|
  conf.cc = ENV['CC'] || 'gcc'
  conf.ld = ENV['LD'] || 'gcc'
  conf.ar = ENV['AR'] || 'ar'
  # conf.cxx = conf.cc
  # conf.objcc = conf.cc
  # conf.asm = conf.cc
  # conf.yacc = 'bison'
  # conf.gperf = 'gperf'
  # conf.cat = 'cat'
  # conf.git = 'git'

  conf.cflags << (ENV['CFLAGS'] || %w(-g -O3 -Wall -Werror-implicit-function-declaration))
  conf.ldflags << (ENV['LDFLAGS'] || %w(-lm))
  # conf.cxxflags = []
  # conf.objccflags = []
  # conf.asmflags = []

  # conf.gem 'doc/mrbgems/ruby_extension_example'
  # conf.gem 'doc/mrbgems/c_extension_example'
  # conf.gem 'doc/mrbgems/c_and_ruby_extension_example'
  # conf.gem :git => 'git@github.com:masuidrive/mrbgems-example.git', :branch => 'master'
end

MRuby::CrossBuild.new('arm-cortex-m4') do |conf|
  TOOLCHAIN_PREFIX = "arm-none-eabi-"
  conf.cc = TOOLCHAIN_PREFIX + (ENV['CC'] || 'gcc')
  conf.ld = TOOLCHAIN_PREFIX + (ENV['LD'] || 'gcc')
  conf.ar = TOOLCHAIN_PREFIX + (ENV['AR'] || 'ar')
  # conf.cxx = 'gcc'
  # conf.objcc = 'gcc'
  # conf.asm = 'gcc'
  # conf.yacc = 'bison'
  # conf.gperf = 'gperf'
  # conf.cat = 'cat'
  # conf.git = 'git'

  conf.cflags << %w(-g -mlittle-endian -mthumb -mcpu=cortex-m4 -mthumb-interwork -mfloat-abi=hard -mfpu=fpv4-sp-d16)

  macros = %w(MRB_HEAP_PAGE_SIZE=256 GC_STEP_SIZE=256)
  conf.cflags << macros.map {|m| "-D\"#{m}\""}

  #conf.ldflags = %w(-s -static)

  # conf.cxxflags << []
  # conf.objccflags << []
  # conf.asmflags << []

  # conf.gem 'doc/mrbgems/ruby_extension_example'
  # conf.gem 'doc/mrbgems/c_extension_example'
  # conf.gem 'doc/mrbgems/c_and_ruby_extension_example'
end
