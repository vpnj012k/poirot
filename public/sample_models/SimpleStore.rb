data UserID
data OrderID # order ID
secret data SessionID 
secret data Password # password

trusted component MyStore [
  passwords: UserID ** Password,
  sessions: UserID ** SessionID,
  orders: (updatable UserID ** OrderID)
]{    
  typeOf HttpServer

  op Login[uid: UserID, pwd: Password, ret: SessionID] {
    allows { pwd == passwords[uid] and ret == sessions[uid]}
  }
  
  op PlaceOrder[uid: UserID, oid: OrderID] {
    updates { orders.insert(uid**oid) }
  }
  
  op ListOrder[uid: UserID, ret: OrderID] {
    allows { ret == orders[uid] }
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
