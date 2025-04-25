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
    totalVotes: Int as uint32;
    
    init(data: Init) {
        self.proposalId = data.proposalId;
        self.votingEndingAt = data.votingEndingAt;
        self.yesCount = 0;
        self.noCount = 0;
        self.voters = emptyMap();
        self.totalVotes = 0;
    }

    // Empty handler for deployment
    receive() { }

    // Message handler for voting
    receive(msg: Vote) {
        throwUnless(100, now() < self.votingEndingAt);
        throwUnless(101, self.totalVotes < 100);
        throwUnless(702, self.voters.get(sender()) == null);
        
        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        
        self.voters.set(sender(), true);
        self.totalVotes += 1;
        
        // Reimburse excess funds
        let excess = myBalance() - ton("0.01"); // 0.01 TON for gas
        if (excess > 0) {
            send(SendParameters{
                to: sender(),
                value: excess,
                bounce: false,
                body: emptyCell()
            });
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
