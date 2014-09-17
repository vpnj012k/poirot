
require 'slang/slang_dsl'

include Slang::Dsl
Component = Slang::Model::Module
AllData = Slang::Model::Data

Slang::Dsl.view :PoirotModel do

# Example e-store model in Poirot
data UserID
data OrderID # order ID
secret data SessionID 
secret data Password # password

trusted component MyStore [
  passwords: (updatable UserID ** Password),
  sessions: (updatable UserID ** SessionID),
  orders: (updatable UserID ** OrderID)
]{    
  typeOf HttpServer

  op Signup[uid: UserID, pwd: Password] {
    allows { no passwords[uid] }
    updates { passwords.insert(uid**pwd) }
  }
    
  op Login[uid: UserID, pwd: Password, ret: SessionID] {
    allows { pwd == passwords[uid] and ret == sessions[uid]}
  }
  
  op PlaceOrder[uid: UserID, oid: OrderID] {
    updates { orders.insert(uid**oid) }
  }
  
   op ListOrder[sid: SessionID, ret: OrderID] {
    allows { ret == orders[sessions.(sid)] }
  }

  config {
    contains(passwords, Customer.myId, Customer.myPwd) and
    uniqueAssignments(sessions)
  }
 
}

trusted component Customer [
  myId: UserID,
  myPwd: Password
]{
  typeOf Browser

  calls { MyStore::Login }
  calls { MyStore::PlaceOrder }
  calls { MyStore::ListOrder }
}

policy myPolicy {
  confidential(MyStore.orders,Customer.myId)
}

  component EvilServer {
    typeOf HttpServer
    op EvilHttpReq[in: (set AllData), ret: AllData] 
  }

  component EvilClient {
    typeOf Browser
  }
end
