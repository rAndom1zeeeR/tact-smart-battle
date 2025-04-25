message Vote {
    value: Bool;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
    totalVoters: Int as uint32;
}

struct Init {
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
}

contract Proposal {
    override const storageReserve: Int = ton("0.0125");
    
    proposalId: Int as uint32;
    votingEndingAt: Int as uint32;
    yesCount: Int as uint32 = 0;
    noCount: Int as uint32 = 0;
    totalVoters: Int as uint32 = 0;
    voters: map<Address, Bool>;
    
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.voters = emptyMap();
    }

    receive() { }

    receive(msg: Vote) {
        throwUnless(100, now() < self.votingEndingAt);
        throwUnless(101, self.voters.get(sender()) == null);
        throwUnless(102, context().value >= getForwardFee(1, 256 + 1, false) + ton("0.01"));
        throwUnless(103, self.totalVoters < 50);
        self.voters.set(sender(), true);
        self.totalVoters += 1;
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        
        let excess = context().value - ton("0.01");
        if (excess > 0) {
            send(SendParameters{
                to: sender(),
                value: excess,
                bounce: false,
                body: emptyCell()
            });
        }
    }

    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.noCount,
            totalVoters: self.totalVoters
        };
    }
}
