message Vote {
    value: Bool;
}

struct ProposalState {
    yesCount: Int as uint32;
    noCount: Int as uint32;
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
    voters: map<Address, Bool> = emptyMap();
    
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
    }

    receive() {}

    receive(msg: Vote) {
        throwUnless(100, myBalance() >= getForwardFee(1, 256 + 1, true));
        throwUnless(101, self.voters.get(sender()) == null);
        throwUnless(102, now() < self.votingEndingAt);
        throwUnless(103, self.yesCount + self.noCount < 10);
        self.voters.set(sender(), true);
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        
        if (myBalance() > 0) {
            cashback(sender());
        }
    }

    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.noCount
        };
    }
}
