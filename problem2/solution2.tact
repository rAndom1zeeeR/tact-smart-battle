struct ProposalInit {
    master: Address;
    proposalId: Int as uint32;
}

message DeployNewProposal {
    votingEndingAt: Int as uint32;
}

contract ProposalMaster {
    nextProposalId: Int as uint32;
    
    init() {
        self.nextProposalId = 0;
    }
    
    receive() { }

    receive(msg: DeployNewProposal) {
        throwUnless(100, now() < msg.votingEndingAt);
        
        // Deploy a new Proposal contract
        let proposalInit: ProposalInit = ProposalInit{
            master: myAddress(),
            proposalId: self.nextProposalId
        };
        
        // Deploy the new proposal contract
        deploy(DeployParameters{
            value: 0,
            mode: SendRemainingValue,
            bounce: true,
            body: beginCell().storeUint(msg.votingEndingAt, 32).endCell(),
            init: initOf Proposal(proposalInit)
        });
        
        // Increment the next proposal ID
        self.nextProposalId += 1;
    }

    get fun nextProposalId(): Int {
        return self.nextProposalId;
    }
}

// ==============================================================================

message Vote {
    value: Bool;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    master: Address;
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32 = 0;
    yesCount: Int as uint32 = 0;
    noCount: Int as uint32 = 0;
    voters: map<Address, Bool>;

    init(data: ProposalInit) {
        self.master = data.master;
        self.proposalId = data.proposalId;
        self.voters = emptyMap();
    }

    receive(msg: Slice) {
        throwIf(2025, sender() != self.master);
        self.votingEndingAt = msg.loadUint(32);
        throwUnless(101, now() < self.votingEndingAt);
    }

    receive(msg: Vote) {
        throwUnless(102, now() < self.votingEndingAt);
        throwUnless(103, self.voters.get(sender()) == null);
        throwUnless(104, self.yesCount + self.noCount < 100);
        self.voters.set(sender(), true);
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
    }

    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.noCount,
            master: self.master,
            proposalId: self.proposalId,
            votingEndingAt: self.votingEndingAt
        };
    }
}
