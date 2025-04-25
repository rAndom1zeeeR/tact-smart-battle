//
// Scalable single-proposal Voting Contract + Refunds and gas management
//

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
    voters: map<Address, Bool>;

    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.voters = emptyMap();
    }

    // deploy
    receive() { }

    receive(msg: Vote) {
        throwUnless(700, context().value >= 100_000_000);
        throwUnless(701, context().value >= getForwardFee(1, 256 + 1, false));
        let sender = sender();
        throwUnless(702, now() < self.votingEndingAt);
        throwUnless(703, self.voters.get(sender) == null);
        throwUnless(704, self.yesCount + self.noCount < 50);
        self.voters.set(sender, true);
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        cashback(sender);
    }

    get fun proposalState(): ProposalState {
        return ProposalState {
            yesCount: self.yesCount,
            noCount: self.noCount
        };
    }
}
