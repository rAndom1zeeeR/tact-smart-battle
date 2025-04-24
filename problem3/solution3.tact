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
    yesCount: Int as uint32;
    noCount: Int as uint32;
    voters: map<Address, Bool>;
    
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.yesCount = 0;
        self.noCount = 0;
        self.voters = emptyMap();
    }

    receive() { }

    receive(msg: Vote) {
        throwUnless(700, now() < self.votingEndingAt);
        let sender = sender();
        throwUnless(701, self.voters.get(sender) == null);
        let fwdFee: Int = getForwardFee(1, 256 + 1, false);
        throwUnless(702, myBalance() >= fwdFee + ton("0.01"));
        let totalVotes = self.yesCount + self.noCount;
        throwUnless(703, totalVotes < 50);
        self.voters.set(sender, true);
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        
        let excess = myBalance() - ton("0.01");
        if (excess > 0) {
            send(SendParameters{
                to: sender,
                value: excess,
                bounce: false,
                body: emptyCell()
            });
        }
    }

    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.noCount
        };
    }
}
