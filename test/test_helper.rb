$LOAD_PATH.unshift File.expand_path('../../../arby/lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../../alloy_ruby/lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../../sdg_utils/lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'logger'
require 'nilio'
require 'set'
require 'test/unit'
require 'pry'

require 'arby/arby'
require 'sdg_utils/testing/assertions'
require 'sdg_utils/testing/smart_setup'

Arby.set_default :logger => Logger.new(NilIO.instance) # Logger.new(STDOUT)
