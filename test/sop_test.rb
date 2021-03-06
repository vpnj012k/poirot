#!/usr/bin/env ruby

require_relative 'test_helper'

# $LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
# $LOAD_PATH.unshift File.expand_path('../../../alloy_ruby/lib', __FILE__)
# $LOAD_PATH.unshift File.expand_path('../../../arby/lib', __FILE__)

require 'sdsl/alloy_printer'
require 'sdsl/myutils'
require 'sdsl/options.rb'

require 'slang/case_studies/sop/fb_ad_mashup'
require 'slang/case_studies/sop/sop'
require 'slang/case_studies/sop/postMessage'
# require "slang/case_studies/http/http"
# require "slang/case_studies/paywall/referer_interaction"
# require "slang/case_studies/paywall/cookie_replay"
# require "slang/case_studies/paywall/javascript_hampering"

def dump(view, name, color="beige")
  dumpAlloy(view, "../alloy/#{name}.als")
  drawView(view, "../alloy/#{name}.dot", color)
end

Options.setOpt(:OPT_TIMELESS, false)
Options.setOpt(:OPT_GLOBAL_DATA, true)
Options.setOpt(:DRAW_DATATYPES, false)

sop_view = eval("SOP").meta.to_sdsl
mashup_view = eval("Mashup").meta.to_sdsl
postmessage_view = eval("PostMessageComm").meta.to_sdsl

# http_view = eval("HTTP").meta.to_sdsl
# cookie_replay_view = eval("CookieReplay").meta.to_sdsl
# javascript_hampering_view = eval("JavascriptHampering").meta.to_sdsl
# referer_interaction_view = eval("RefererInteraction").meta.to_sdsl

dump(sop_view, "sop")
dump(mashup_view, "mashup")
dump(postmessage_view, "postmessage")
# dump(http_view, "http")
# dump(cookie_replay_view, "cookie_replay")
# dump(javascript_hampering_view, "javascript_hampering")
# dump(referer_interaction_view, "referer_interaction")

# mv = composeViews(http_view, cookie_replay_view)
# mv = composeViews(mv, javascript_hampering_view)
# mv = composeViews(mv, referer_interaction_view)
mv = composeViews(sop_view, postmessage_view)
mv = composeViews(mashup_view, mv, {
                    :Module => {
                      "AdClient" => "Script",
                      "AdServer" => "HTTPServer",
                      "FBClient" => "Script",
                      "FBServer" => "HTTPServer",
                    },
                    :Exports => {
                      "FBServer__GetProfile" => "HTTPServer__GET",
                      "AdClient__GetAd" => "HTTPServer__GET", 
                      "AdServer__SendInfo" => "HTTPServer__POST",
                    },
                    :Invokes => {
                      # "DisplayProfile" => "Resp",
                      # "DisplayAd" => "Resp",
                      # "SendInfo" => "POST",
                    },
                    :Data => {
                      "ProfilePage" => "HTTPResp",
                      "ProfileData" => "DOM"
                    }
                  })

dump(mv, "merged")
