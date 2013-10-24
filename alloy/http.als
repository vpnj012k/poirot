open models/basic
open models/crypto[Data]

-- module Server
one sig Server extends Module {
	Server__responses : URL set -> lone HTML,
}{
	all o : this.sends[Browser__SendResp] | triggeredBy[o,Server__SendReq]
	all o : this.sends[Browser__SendResp] | o.(Browser__SendResp <: Browser__SendResp__resp) = Server__responses[o.trigger.((Server__SendReq <: Server__SendReq__url))]
}

-- module Browser
one sig Browser extends Module {
}{
	all o : this.sends[User__DisplayHTML] | triggeredBy[o,Browser__SendResp]
	all o : this.sends[User__DisplayHTML] | o.(User__DisplayHTML <: User__DisplayHTML__html) = o.trigger.((Browser__SendResp <: Browser__SendResp__resp))
	all o : this.sends[Server__SendReq] | triggeredBy[o,Browser__Visit]
	all o : this.sends[Server__SendReq] | o.(Server__SendReq <: Server__SendReq__url) = o.trigger.((Browser__Visit <: Browser__Visit__url))
}

-- module User
one sig User extends Module {
}

-- fact trustedModuleFacts
fact trustedModuleFacts {
	TrustedModule = Server + Browser
}

-- operation Server__SendReq
sig Server__SendReq extends Op {
	Server__SendReq__url : lone URL,
	Server__SendReq__headers : set Pair,
}{
	args = Server__SendReq__url + Server__SendReq__headers
	no ret
	sender in Browser
	receiver in Server
}

-- operation Browser__SendResp
sig Browser__SendResp extends Op {
	Browser__SendResp__resp : lone HTML,
	Browser__SendResp__headers : set Pair,
}{
	args = Browser__SendResp__resp + Browser__SendResp__headers
	no ret
	sender in Server
	receiver in Browser
}

-- operation Browser__Visit
sig Browser__Visit extends Op {
	Browser__Visit__url : lone URL,
}{
	args = Browser__Visit__url
	no ret
	sender in User
	receiver in Browser
}

-- operation User__DisplayHTML
sig User__DisplayHTML extends Op {
	User__DisplayHTML__html : lone HTML,
}{
	args = User__DisplayHTML__html
	no ret
	sender in Browser
	receiver in User
}

-- datatype declarations
sig Addr extends Data {
}{
	no fields
}
sig Name extends Data {
}{
	no fields
}
sig Value extends Data {
}{
	no fields
}
sig HTML extends Data {
}{
	no fields
}
sig Pair extends Data {
	Pair__n : lone Name,
	Pair__v : lone Value,
}{
	fields = Pair__n + Pair__v
}
sig URL extends Data {
	URL__addr : lone Addr,
	URL__queries : set Pair,
}{
	fields = URL__addr + URL__queries
}
sig OtherData extends Data {}{ no fields }


fun RelevantOp : Op -> Step {
	{o : Op, t : Step | o.post = t and o in SuccessOp}
}

run SanityCheck {
	all m : Module |
		some sender.m & SuccessOp
} for 1 but 7 Data, 7 Step, 6 Op

check Confidentiality {
   Confidentiality
} for 1 but 7 Data, 7 Step, 6 Op

-- check who can create CriticalData
check Integrity {
   Integrity
} for 1 but 7 Data, 7 Step, 6 Op
