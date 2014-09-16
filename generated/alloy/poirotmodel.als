open libraryWeb/WebBasic
open libraryWeb/Redirect

-- module MyStore
one sig MyStore extends HttpServer {
	MyStore__passwords : UserID set -> lone Password,
	MyStore__sessions : UserID set -> lone SessionID,
	MyStore__orders : (UserID set -> lone OrderID) -> set Op,
}{
	all o : this.receives[MyStore__Login] | ((o.MyStore__Login__pwd) = MyStore__passwords[(o.MyStore__Login__uid)] and (o.MyStore__Login__ret) = MyStore__sessions[(o.MyStore__Login__uid)])
	all o : this.receives[MyStore__PlaceOrder] | MyStore__orders.(o.next) = (MyStore__orders.o + ((o.MyStore__PlaceOrder__uid) -> (o.MyStore__PlaceOrder__oid)))
	all o : this.receives[MyStore__ListOrder] | (o.MyStore__ListOrder__ret) = MyStore__orders.o[(MyStore__sessions.(o.MyStore__ListOrder__sid))]
	all o : Op - last | let o' = o.next | MyStore__orders.o' != MyStore__orders.o implies (o in MyStore__PlaceOrder & SuccessOp and o.receiver = this)
	this.initAccess in this.MyStoreInitData
	this.MyStoreFieldData in this.initAccess
}
fun MyStoreFieldData[m : Module] : set Data {
	UserID.(m.MyStore__passwords) + (m.MyStore__passwords).Password + UserID.(m.MyStore__sessions) + (m.MyStore__sessions).SessionID + UserID.((m.MyStore__orders).first) + ((m.MyStore__orders).first).OrderID
}
fun MyStoreInitData[m : Module] : set Data {
	NonCriticalData + UserID.(m.MyStore__passwords) + (m.MyStore__passwords).Password + UserID.(m.MyStore__sessions) + (m.MyStore__sessions).SessionID + UserID.((m.MyStore__orders).first) + ((m.MyStore__orders).first).OrderID
}

-- module Customer
one sig Customer extends Browser {
	Customer__myId : one UserID,
	Customer__myPwd : one Password,
}{
	this.initAccess in this.CustomerInitData
	this.CustomerFieldData in this.initAccess
}
fun CustomerFieldData[m : Module] : set Data {
	(m.Customer__myId) + (m.Customer__myPwd)
}
fun CustomerInitData[m : Module] : set Data {
	NonCriticalData + (m.Customer__myId) + (m.Customer__myPwd)
}

-- module EvilServer
one sig EvilServer extends HttpServer {
}{
	this.initAccess in this.EvilServerInitData
}
fun EvilServerInitData[m : Module] : set Data {
	Data - (ConfidentialData + (CriticalData & TrustedModule.initAccess))
}

-- module EvilClient
one sig EvilClient extends Browser {
}{
	this.initAccess in this.EvilClientInitData
}
fun EvilClientInitData[m : Module] : set Data {
	Data - (ConfidentialData + (CriticalData & TrustedModule.initAccess))
}


-- fact trustedModuleFacts
fact trustedModuleFacts {
	TrustedModule = MyStore + Customer
}

-- operation MyStore__Login
sig MyStore__Login in HTTPReq {
	MyStore__Login__uid : one UserID,
	MyStore__Login__pwd : one Password,
	MyStore__Login__ret : one SessionID,
}{
	args = MyStore__Login__uid + MyStore__Login__pwd
	ret = MyStore__Login__ret
	TrustedModule & sender in Customer
	TrustedModule & receiver in MyStore
}

-- operation MyStore__PlaceOrder
sig MyStore__PlaceOrder in HTTPReq {
	MyStore__PlaceOrder__uid : one UserID,
	MyStore__PlaceOrder__oid : one OrderID,
}{
	args = MyStore__PlaceOrder__uid + MyStore__PlaceOrder__oid
	no ret
	TrustedModule & sender in Customer
	TrustedModule & receiver in MyStore
}

-- operation MyStore__ListOrder
sig MyStore__ListOrder in HTTPReq {
	MyStore__ListOrder__sid : one SessionID,
	MyStore__ListOrder__ret : one OrderID,
}{
	args = MyStore__ListOrder__sid
	ret = MyStore__ListOrder__ret
	TrustedModule & sender in Customer
	TrustedModule & receiver in MyStore
}

-- operation EvilServer__EvilHttpReq
sig EvilServer__EvilHttpReq in HTTPReq {
	EvilServer__EvilHttpReq__in : set Data,
	EvilServer__EvilHttpReq__ret : one Data,
}{
	args = EvilServer__EvilHttpReq__in
	ret = EvilServer__EvilHttpReq__ret
	TrustedModule & receiver in EvilServer
}

-- datatype declarations
sig UserID extends Data {
}
sig OrderID extends Data {
}
sig SessionID extends Data {
}
sig Password extends Data {
}
sig OtherData extends Data {}

-- fact criticalDataFacts
fact criticalDataFacts {
	SessionID + Password in CriticalData
}

-- fact operationList
fact operationList {
	Op = MyStore__Login + MyStore__PlaceOrder + MyStore__ListOrder + EvilServer__EvilHttpReq
	disjointOps[MyStore__Login, MyStore__PlaceOrder]
	disjointOps[MyStore__Login, MyStore__ListOrder]
	disjointOps[MyStore__Login, EvilServer__EvilHttpReq]
	disjointOps[MyStore__PlaceOrder, MyStore__ListOrder]
	disjointOps[MyStore__PlaceOrder, EvilServer__EvilHttpReq]
	disjointOps[MyStore__ListOrder, EvilServer__EvilHttpReq]
}
assert myPolicy {
confidential[(MyStore__orders.Op), Customer__myId]
}


fact GenericFacts {
  Op in SuccessOp
  all o : Op | 
    (o.sender in TrustedModule and some o.args & CriticalData) implies 
      o.receiver in TrustedModule
}

check myPolicy for 2 but 4 Data, 4 Op, 4 Step, 4 Module

run SanityCheck {
  some MyStore__Login & SuccessOp
  some MyStore__PlaceOrder & SuccessOp
  some MyStore__ListOrder & SuccessOp
  no (receiver + sender).UntrustedModule & SuccessOp
} for 2 but 4 Data, 4 Op, 4 Step, 4 Module


check Confidentiality {
  Confidentiality
} for 2 but 4 Data, 4 Op, 4 Step, 4 Module


-- check who can create CriticalData
check Integrity {
  Integrity
} for 2 but 4 Data, 4 Op, 4 Step, 4 Module

fun RelevantData : Data -> Step {
	{ d : Data, s : Step | 
		some m : Module | 
			m-> d -> s in this/receives
	}
}
fun talksTo : Module -> Module -> Step {
	{from, to : Module, s : Step | from = s.o.sender and to = s.o.receiver }
}
fun RelevantOp : Op -> Step {
	{ o' : SuccessOp, s : Step |
		o' = s.o
	}
}
fun receives : Module -> Data -> Step {
	{ m : Module, d : Data, s : Step | 
		(m = s.o.receiver and d in s.o.args) or (m = s.o.sender and d in s.o.ret)}
}
