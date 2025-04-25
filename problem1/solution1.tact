//
// Single-proposal Voting Contract
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
        throwUnless(100, now() < self.votingEndingAt);
        throwUnless(101, self.voters.get(sender()) == null);
        throwUnless(102, self.yesCount + self.noCount < 100);
        
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        
        self.voters.set(sender(), true);        
        // Reimburse excess funds
        let excess = myBalance() - ton("0.01");
        if (excess > 0) {
            cashback(sender());
        }
    }

    // Getter for retrieving voting results
    get fun proposalState(): ProposalState {
        return ProposalState{
            yesCount: self.yesCount,
            noCount: self.noCount
        };
    }
}
