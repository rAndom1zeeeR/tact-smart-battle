import "@stdlib/deploy";

// Messages
message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

message DeployNewProposalWithCashBack {
    votingEndingAt: Int as uint32;
    sender: Address;
}

message Vote {
    value: Bool;
}

// Structs
struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

// ProposalMaster contract
contract ProposalMaster with Deployable {
    proposalId: Int = 0;
    
    receive() {
        if(context().value < ton("0.01")) {
            return;
        }
        if (myBalance() >= ton("0.01")) {
            send(SendParameters{
                to: sender(),
                value: myBalance() - ton("0.011"),
                mode: SendIgnoreErrors,
                bounce: true
            });
        }
    }
    
    receive(msg: DeployNewProposal) {
        if(msg.votingEndingAt <= now()) { 
            throw(104);
        }
        let proposalInit: ProposalInit = ProposalInit{
            master: myAddress(),
            proposalId: self.proposalId
        };
        let init: StateInit = initOf Proposal(proposalInit);
        send(SendParameters{
            to: contractAddress(init),
            value: 0,
            mode: SendRemainingValue,
            code: init.code,
            data: init.data,
            body: DeployNewProposalWithCashBack{
                votingEndingAt: msg.votingEndingAt,
                sender: sender()
            }.toCell(),
        });
        self.proposalId += 1;
        cashback(sender());
    }
    
    get fun nextProposalId(): Int {
        return self.proposalId;
    }
}

// Proposal contract
contract Proposal {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32 = 0;
    yesCount: Int as uint32 = 0;
    noCount: Int as uint32 = 0;
    voted: map<Address, Bool>;
    master: Address;
    
    init(data: ProposalInit) {
        throwUnless(2025, sender() == data.master);
        self.proposalId = data.proposalId;
        self.master = data.master;
    }

    receive(msg: DeployNewProposalWithCashBack) {
        throwUnless(2025, sender() == self.master);
        self.votingEndingAt = msg.votingEndingAt;
        cashback(msg.sender)
    }
    
    receive(msg: Vote) {
        let sender = sender();
        throwUnless(101, now() < self.votingEndingAt);
        throwUnless(102, self.voted.get(sender) != true);
        throwUnless(103, self.yesCount + self.noCount < 100);
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        self.voted.set(sender, true);
        cashback(sender());
    }
    
    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.noCount,
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt
        };
    }
}