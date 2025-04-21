// Scalable Voting Contract for a Single Proposal

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
        let now = now();
        if (now >= self.votingEndingAt) {
            throw(100); // Voting has ended
        }
        
        // Check if vote limit has been reached
        if (self.totalVotes >= 100) {
            throw(101); // Maximum votes reached
        }

        let senderAddr = sender();
        if (self.voters.get(senderAddr) != null) {
            throw(102); // Voter has already voted
        }
        self.voters.set(senderAddr, true);
        self.totalVotes += 1;

        if (msg.value) {
            self.yesCount += 1;
        } else {
            self.noCount += 1;
        }
        
        // Reimburse excess funds
        let excess = myBalance() - 10000000; // 0.01 TON for gas
        if (excess > 0) {
            send(SendParameters{
                to: senderAddr,
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
