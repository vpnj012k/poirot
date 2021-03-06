require 'slang/slang_dsl'
require 'slang/case_studies/http/http.rb'

include Slang::Dsl

Slang::Dsl.view :Paywall do
  include HTTP

  abstract data Page
  critical data Article do
    belongs_to Page
  end
  data Link

  trusted NYTimes [
    articles: Link ** Article,
    limit: Int
  ] do
    creates Article
    belongs_to Server, Browser

    op GetLink [link: Link, numAccessed: Int] do
      belongs_to Server::SendReq
      guard { numAccessed < limit }
      sends { Client::SendPage[articles[link], numAccessed + 1] }
    end
  end

  trusted Client [
    numAccessed: (dynamic Int)
  ] do
    op SendPage[page: Page, newCounter: Int] do
      effects { self.numAccessed = newCounter }
      sends { Reader::DisplayPage[page] }
    end
    op SelectLink[link: Link] do
      sends { NYTimes::GetLink[link, numAccessed] }
    end
  end

  mod Reader do
    op DisplayPage[page: Page] do end
    sends { Client::SelectLink }
  end

end



# require 'slang/slang_dsl'

# include Slang::Dsl

# Slang::Dsl.view :Paywall do

#   abstract data Page
#   critical data Article < Page
#   data Link

#   trusted NYTimes [
#     articles: Link ** Article,
#     limit: Int
#   ] do
#     creates Article

#     op GetLink[link: Link, numAccessed: Int] do
#       guard { numAccessed < limit }
#       sends { Client::SendPage[articles[link], numAccessed + 1] }
#     end
#   end

#   trusted Client [
#     numAccessed: (dynamic Int)
#   ] do
#     op SendPage[page: Page, newCounter: Int] do
#       effects { self.numAccessed = newCounter }
#       sends { Reader::DisplayPage[page] }
#     end
#     op SelectLink[link: Link] do
#       sends { NYTimes::GetLink[link, numAccessed] }
#     end    
#   end

#   mod Reader do
#     op DisplayPage[page: Page] do end
#     sends { Client::SelectLink }
#   end

# end

